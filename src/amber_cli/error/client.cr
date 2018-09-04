require "./page"

module Error
  class Client < Page
    EX_ECR_SCRIPT = "#{__DIR__}/exception_page_client_script.js"

    def initialize(context : HTTP::Server::Context, @ex : Exception)
      super(context, @ex.message)
      @title = "Error #{context.response.status_code}"
      @frames = generate_frames_from(@ex.inspect_with_backtrace)
      @reload_code = File.read(File.join(Dir.current, EX_ECR_SCRIPT))
    end
  end
end