require "./spec_helper"

describe CLI do
  it "enables colorized log utput" do
    CLI.toggle_colors(false).should eq true
  end

  it "load amber.yml config" do
    CLI.config == CLI::Config
  end

  it "generates config yml" do
    CLI.generate_config
    File.exists?(CLI::AMBER_YML).should eq true
  end
end
