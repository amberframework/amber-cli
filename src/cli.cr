require "environment"
require "./cli/main_command"
require "./cli/config"
require "./cli/file_watcher"
require "./cli/process_runner"

module CLI
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
    File.write(AMBER_YML, CLI.config.to_yaml)
  end
end
