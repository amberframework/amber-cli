require "../spec_helper"
require "../cli_helper"
require "environment/support/file_encryptor"

include AmberCLIHelper

module AmberCLI
  describe "amber encrypt" do
    cleanup
    scaffold_app(TESTING_APP)
    MainCommand.run ["encrypt", "test"]

    it "creates a hidden .test.enc file" do
      File.exists?("config/environments/.test.enc").should be_true
    end

    it "unencrypts .test.enc" do
      String.new(Support::FileEncryptor.read("./config/environments/.test.enc")).should contain "port: 3000"
    end

    it "creates a 44 characters secret key in .encryption_key" do
      File.read(".encryption_key").size.should eq 44
    end

    cleanup
  end
end
