require "cli"
require "../process_runner"

module AmberCLI
  class MainCommand < ::Cli::Supercommand
    command "w", aliased: "watch"

    class Watch < ::Cli::Command
      class Options
        bool "--no-color", desc: "# Disable colored output", default: false
        help
      end

      class Help
        header <<-HEADER
        Starts amber development server and rebuilds on file changes.
        See `.amber.yml` for more settings.
        HEADER
      end

      def run
        AmberCLI.toggle_colors(options.no_color?)

        process_runner = ProcessRunner.run(
          watch_config = AmberCLI.config.watch,
          project_name = AmberCLI.settings.name.colorize(:light_cyan).to_s,
          host = AmberCLI.settings.host,
          port = AmberCLI.settings.port,
          logger = AmberCLI.logger
        )
      end
    end
  end
end
