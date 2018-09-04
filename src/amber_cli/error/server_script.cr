module Error
  class ServerScript
    def initialize(@error_id : String)
    end

    ECR.def_to_s "#{__DIR__}/exception_page_server_script.js"
  end
end