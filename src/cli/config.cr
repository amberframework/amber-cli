require "yaml"

module CLI
  class Config
    alias Watch = Hash(String, Hash(String, Array(String)))

    getter database : String = "pg"
    getter language : String = "slang"
    getter model : String = "granite"
    getter recipe : String?
    getter recipe_source : String?

    def initialize
      @watch = Watch.new
    end

    private def app_name
      File.basename(Dir.current)
    end

    YAML.mapping(
      database: {type: String, default: @database},
      language: {type: String, default: @language},
      model: {type: String, default: @model},
      recipe: String?,
      recipe_source: String?,
      watch: {type: Watch, default: {
        "server" => {
          "files" => [
            "src/**/*.cr",
            "src/**/*.#{@language}",
            "config/**/*.cr"
          ],
          "commands" => [
            "shards build -p --no-color",
            "bin/#{app_name}"
          ]
        }
      }
    })
  end
end
