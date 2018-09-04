module AmberCLI
  class WebSocketChannel < Teeplate::FileTree
    include AmberCLI::Helpers
    directory "#{__DIR__}/channel"
    @name : String

    def initialize(@name)
      add_dependencies <<-DEPENDENCY
      require "../src/channels/**"
      DEPENDENCY
    end
  end
end
