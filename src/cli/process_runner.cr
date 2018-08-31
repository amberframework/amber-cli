require "http"
require "process"
require "./file_watcher"

module CLI
  class ExceptionPage
    struct Frame
      property app : String,
        args : String,
        context : String,
        index : Int32,
        file : String,
        line : Int32,
        info : String,
        snippet = [] of Tuple(Int32, String, Bool)

      def initialize(@app, @context, @index, @file, @args, @line, @info, @snippet)
      end
    end

    @params : Hash(String, String)
    @headers : Hash(String, Array(String))
    @session : Hash(String, HTTP::Cookie)
    @method : String
    @path : String
    @message : String
    @query : String
    @reload_code = ""
    @frames = [] of Frame

    def initialize(context : HTTP::Server::Context, @message : String)
      @params = context.request.query_params.to_h
      @headers = context.response.headers.to_h
      @method = context.request.method
      @path = context.request.path
      @url = "#{context.request.host_with_port}#{context.request.path}"
      @query = context.request.query_params.to_s
      @session = context.response.cookies.to_h
    end

    def generate_frames_from(message : String)
      generated_frames = [] of Frame
      if frames = message.scan(/\s([^\s\:]+):(\d+)([^\n]+)/)
        frames.each_with_index do |frame, index|
          snippets = [] of Tuple(Int32, String, Bool)
          file = frame[1]
          filename = file.split('/').last
          linenumber = frame[2].to_i
          linemsg = "#{file}:#{linenumber}#{frame[3]}"
          if File.exists?(file)
            lines = File.read_lines(file)
            lines.each_with_index do |code, codeindex|
              if (codeindex + 1) <= (linenumber + 5) && (codeindex + 1) >= (linenumber - 5)
                highlight = (codeindex + 1 == linenumber) ? true : false
                snippets << {codeindex + 1, code, highlight}
              end
            end
          end
          context = "all"
          app = case file
                when .includes?("/crystal/")
                  "crystal"
                when .includes?("/amber/")
                  "amber"
                when .includes?("lib/")
                  "shards"
                else
                  context = "app"
                  CLI.settings.name.as(String)
                end
          generated_frames << Frame.new(app, context, index, file, linemsg, linenumber, filename, snippets)
        end
      end
      if self.class.name == "ExceptionPageServer"
        generated_frames.reverse
      else
        generated_frames
      end
    end

    ECR.def_to_s "#{__DIR__}/exception_page.ecr"
  end

  class ExceptionPageClient < ExceptionPage
    EX_ECR_SCRIPT = "../../exception_page_client_script.js"

    def initialize(context : HTTP::Server::Context, @ex : Exception)
      super(context, @ex.message)
      @title = "Error #{context.response.status_code}"
      @frames = generate_frames_from(@ex.inspect_with_backtrace)
      @reload_code = File.read(File.join(Dir.current, EX_ECR_SCRIPT))
    end
  end

  class ExceptionPageServer < ExceptionPage
    def initialize(context : HTTP::Server::Context, message : String, @error_id : String)
      super(context, message)
      @title = "Build Error"
      @method = "Server"
      @path = Dir.current
      @frames = generate_frames_from(message)
      @reload_code = ExceptionPageServerScript.new(@error_id).to_s
    end
  end

  class ExceptionPageServerScript
    def initialize(@error_id : String)
    end

    ECR.def_to_s "#{__DIR__}/exception_page_server_script.js"
  end

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
      @host = CLI.settings.host
      @port = CLI.settings.port
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
      if watch_config = CLI.config.watch
        run_watcher(watch_config)
      else
        warn "Can't find watch settings, do you want to add default watch settings? (y/n)"
        CLI.generate_config if gets.to_s.downcase == "y"
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
      info "Building project #{CLI.settings.name.colorize(:light_cyan)}"
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
            process = CLI::ProcessRunner.run(command, error: error_io)
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
        process = CLI::ProcessRunner.run(command)
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
        context.response.print ExceptionPageServer.new(context, error_output, error_id).to_s
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
      CLI.logger.debug msg, "Watcher"
    end

    private def info(msg)
      CLI.logger.info msg, "Watcher", :light_cyan
    end

    private def error(msg)
      CLI.logger.error msg, "Watcher", :red
    end

    private def warn(msg)
      CLI.logger.warn msg, "Watcher", :yellow
    end
  end
end
