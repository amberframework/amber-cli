abstract class Command < Cli::Command
  def info(msg)
    AmberCLI.logger.info msg, Class.name, :light_cyan
  end

  def error(msg)
    AmberCLI.logger.error msg, Class.name, :red
  end
end
