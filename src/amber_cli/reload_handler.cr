require "./client_reload"
require "http"

module AmberCLI
  class ReloadHandler
    include HTTP::Handler
    CONTENT_TYPE_HEADER = "Content-Type"

    def initialize(@env : Environment::Env = Amber.env)
      ClientReload.run
    end

    def call(context : HTTP::Server::Context)
      if @env.development? && context.request.headers[CONTENT_TYPE_HEADER].downcase == "text/html"
        context.response.headers["Client-Reload"] = %(true)
      end
      call_next(context)
    end
  end
end
