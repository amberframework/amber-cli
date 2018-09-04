require "environment"
require "./amber_cli/main_command"
require "./amber_cli/config"
require "./amber_cli/file_watcher"
require "./amber_cli/process_runner"
require "./amber_cli/reload_handler"

module AmberCLI
  VERSION = "0.9.0"
  include Environment

  AMBER_YML = ".amber.yml"

  def self.toggle_colors(on_off)
    Colorize.enabled = !on_off
  end

  def self.config
    return Config.from_yaml File.read(AMBER_YML) if File.exists? AMBER_YML
    Config.new
  rescue ex : YAML::ParseException
    logger.error "Couldn't parse #{AMBER_YML} file", "Watcher", :red
    exit 1
  end

  def self.generate_config
    File.write(AMBER_YML, AmberCLI.config.to_yaml)
  end
end
