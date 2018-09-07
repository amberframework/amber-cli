require "http"
require "process"
require "./file_watcher"
require "./error/server"

module AmberCLI
  struct ProcessRunner
    PROCESSES = [] of {::Process, String}
    CLI_IO = ::Process::Redirect::Inherit

    def self.run(command, shell = true, input = CLI_IO, output = CLI_IO, error = CLI_IO)
      ::Process.new(command, shell: shell, input: input, output: output, error: error)
    end

    @host : String
    @port : Int32
    @file_watcher : FileWatcher

    def initialize
      @watch_running = false
      @wait_build = Channel(Bool).new
      @server_files_changed = false
      @notify_counter = 0
      @notify_counter_channel = Channel(Int32).new
      @notify_channel = Channel(Nil).new
      @host = AmberCLI.settings.host
      @port = AmberCLI.settings.port
      @file_watcher = FileWatcher.new

      at_exit do
        kill_processes
      end

      Signal::INT.trap do
        Signal::INT.reset
        exit
      end
    end

    def run
      if watch_config = AmberCLI.config.watch
        run_watcher(watch_config)
      else
        warn "Can't find watch settings, do you want to add default watch settings? (y/n)"
        AmberCLI.generate_config if gets.to_s.downcase == "y"
        exit 1
      end
    rescue ex : KeyError
      error "Error in watch configuration. #{ex.message}"
      exit 1
    end

    private def run_watcher(watch_config)
      begin
        server_config = watch_config["server"]
        spawn watcher("server", server_config["files"], server_config["commands"])
      rescue ex
        error "Error in watch configuration. #{ex.message}"
        exit 1
      end

      watch_config.each do |key, value|
        next if key == "client" || key == "server"
        files = value["files"]
        commands = value["commands"]
        @notify_counter += 1
        spawn watcher(key, files, commands)
      end

      @notify_counter_channel.send @notify_counter
      @notify_counter = @notify_counter_channel.receive
      sleep
    end

    private def watcher(key, files, commands)
      if key != "server"
        @notify_channel.receive
      end
      if files.empty?
        commands.each do |command|
          run_command(command, key)
        end
      else
        loop do
          scan_files(key, files, commands)
          @watch_running = true if key == "server"
          sleep 1
        end
      end
    end

    private def scan_files(key, files, commands)
      file_counter = 0
      @file_watcher.scan_files(files) do |file|
        if @watch_running
          debug "File changed: #{file}"
        end
        file_counter += 1
      end
      if file_counter > 0
        debug "Watching #{file_counter} #{key} files"
        kill_processes(key)
        commands.each do |command|
          if key == "server" && command == commands.first?
            run_build_command(command, commands)
          else
            run_command(command, key)
          end
        end
      end
    end

    private def check_directories
      Dir.mkdir_p("bin")
      if !Dir.exists?("lib")
        error "You need to install dependencies first, execute `shards install`"
        exit 1
      end
    end

    private def run_build_command(command, commands)
      check_directories
      next_server_commands_range = (1...commands.size)
      info "Building project #{AmberCLI.settings.name.colorize(:light_cyan)}"
      spawn do
        error_io = IO::Memory.new
        process = ProcessRunner.run(command, error: error_io)
        PROCESSES << {process, "server"}
        loop do
          if process.terminated?
            handle_terminaded_process(process, error_io, next_server_commands_range)
            break
          end
          sleep 1
        end
      end
    end

    private def handle_terminaded_process(process, error_io, next_server_commands_range)
      exit_status = process.wait.exit_status
      if error_io.empty?
        if exit_status.zero?
          if @watch_running
            kill_processes("server")
          else
            notify_next_processes
          end
          next_server_commands_range.each { @wait_build.send true }
        else
          next_server_commands_range.each { @wait_build.send false }
        end
      else
        handle_error(error_io.to_s)
        next_server_commands_range.each { @wait_build.send false }
      end
    end

    private def notify_next_processes
      notify_counter = @notify_counter_channel.receive
      notify_counter.times { @notify_channel.send nil }
      @notify_counter_channel.send 0
    end

    private def run_command(command, key)
      if key == "server"
        spawn do
          build_sucess? = @wait_build.receive
          if build_sucess?
            error_io = IO::Memory.new
            process = AmberCLI::ProcessRunner.run(command, error: error_io)
            PROCESSES << {process, "server"}
            loop do
              if process.terminated?
                unless error_io.empty?
                  handle_error(error_io.to_s)
                end
                break
              end
              sleep 1
            end
          end
        end
      else
        process = AmberCLI::ProcessRunner.run(command)
        PROCESSES << {process, key}
      end
    end

    private def kill_processes(key = nil)
      PROCESSES.each do |process, owner|
        if process.terminated?
          PROCESSES.delete(process)
        elsif owner == key || key.nil?
          process.kill
        end
      end
    end

    private def error_server(error_output)
      HTTP::Server.new do |context|
        error_id = Digest::MD5.hexdigest(error_output)
        context.response.content_type = "text/html"
        context.response.status_code = 500
        context.response.headers["Client-Reload"] = [error_id]
        context.response.print ::Error::Server.new(context, error_output, error_id).to_s
      end
    end

    private def handle_error(error_output)
      kill_processes("server")
      puts error_output
      new_error_server = ::Process.fork do
        error_server(error_output).listen(@host, @port, reuse_port: true)
      end
      PROCESSES << {new_error_server, "server"}
      error "A server error has been detected see the output above, use CTRL+C to exit"
    end

    private def debug(msg)
      AmberCLI.logger.debug msg, "Watcher"
    end

    private def info(msg)
      AmberCLI.logger.info msg, "Watcher", :light_cyan
    end

    private def error(msg)
      AmberCLI.logger.error msg, "Watcher", :red
    end

    private def warn(msg)
      AmberCLI.logger.warn msg, "Watcher", :yellow
    end
  end
end
