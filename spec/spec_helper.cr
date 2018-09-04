require "spec"
require "./generate_fixtures"
require "./cli_fixtures"
require "./cli_helper"
require "../src/amber_cli"

ENV["AMBER_ENV"] = "test"
ENV[Support::ENCRYPT_ENV] = "mnDiAY4OyVjqg5u0wvpr0MoBkOGXBeYo7_ysjwsNzmw"
TEST_PATH         = "spec/support/sample"
PUBLIC_PATH       = TEST_PATH + "/public"
VIEWS_PATH        = TEST_PATH + "/views"
TEST_APP_NAME     = "test_app"
TESTING_APP       = "./.tmp/#{TEST_APP_NAME}"
APP_TEMPLATE_PATH = "./src/amber/cli/templates/app"
CURRENT_DIR       = Dir.current

AmberCLI.path = "./spec/config/"
AmberCLI.env=(ENV["AMBER_ENV"])
AmberCLI.settings.redis_url = ENV["REDIS_URL"] if ENV["REDIS_URL"]?
AmberCLI.settings.logger = Environment::Logger.new(nil)
