require "./client_reload"
require "http"

module AmberCLI
  # Reload clients browsers using `ClientReload`.
  #
  # NOTE: Amber::Pipe::Reload is intended for use in a development environment.
  # ```
  # pipeline :web do
  #   plug Amber::Pipe::Reload.new
  # end
  # ```
  class ReloadHandler
    include HTTP::Handler

    def initialize(@env : Amber::Environment::Env = Amber.env)
      ClientReload.run
    end

    def call(context : HTTP::Server::Context)
      if @env.development? && context.format == "html"
        context.response.headers["Client-Reload"] = %(true)
      end
      call_next(context)
    end
  end
end
