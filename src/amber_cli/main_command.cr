require "cli"
require "./recipes/recipe"
require "./templates/template"
require "./command"
require "./commands/*"

module AmberCLI
  class MainCommand < ::Cli::Supercommand
    command_name "amber"
    version "Amber CLI (amberframework.org) - v#{VERSION}"

    class Help
      title "\nAmber - Command Line Interface"
      header <<-EOS
        The `amber new` command creates a new Amber application with a default
        directory structure and configuration at the path you specify.

        You can specify extra command-line arguments to be used every time
        `amber new` runs in the .amber.yml configuration file in your project
        root directory

        Note that the arguments specified in the .amber.yml file does not affect the
        defaults values shown above in this help message.

        Usage:
        amber new [app_name] -d [pg | mysql | sqlite] -t [slang | ecr] -m [granite, crecto] --deps
      EOS

      footer <<-EOS
      Example:
        amber new ~/Code/Projects/weblog
        This generates a skeletal Amber installation in ~/Code/Projects/weblog.
      EOS
    end

    class Options
      version desc: "# Prints Amber version"
      help desc: "# Describe available commands and usages"
      string ["-t", "--template"], desc: "# Preconfigure for selected template engine. Options: slang | ecr", default: "slang"
      string ["-d", "--database"], desc: "# Preconfigure for selected database. Options: pg | mysql | sqlite", default: "pg"
      string ["-m", "--model"], desc: "# Preconfigure for selected model. Options: granite | crecto", default: "granite"
      string ["-r", "--recipe"], desc: "# Use a named recipe.  See documentation at https://docs.amberframework.org/amber/cli/recipes.", default: nil
    end
  end
end
