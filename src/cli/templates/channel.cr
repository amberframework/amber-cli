module CLI
  class WebSocketChannel < Teeplate::FileTree
    include CLI::Helpers
    directory "#{__DIR__}/channel"
    @name : String

    def initialize(@name)
      add_dependencies <<-DEPENDENCY
      require "../src/channels/**"
      DEPENDENCY
    end
  end
end
