require "./page"
require "./server_script"

module Error
  class Server < Page
    def initialize(context : HTTP::Server::Context, message : String, @error_id : String)
      super(context, message)
      @title = "Build Error"
      @method = "Server"
      @path = Dir.current
      @frames = generate_frames_from(message)
      @reload_code = ServerScript.new(@error_id).to_s
    end
  end
end