abstract class Command < Cli::Command
  def info(msg)
    CLI.logger.info msg, Class.name, :light_cyan
  end

  def error(msg)
    CLI.logger.error msg, Class.name, :red
  end
end
