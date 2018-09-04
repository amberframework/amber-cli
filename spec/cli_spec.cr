require "./spec_helper"

describe AmberCLI do
  it "enables colorized log utput" do
    AmberCLI.toggle_colors(false).should eq true
  end

  it "load amber.yml config" do
    AmberCLI.config == AmberCLI::Config
  end

  it "generates config yml" do
    AmberCLI.generate_config
    File.exists?(AmberCLI::AMBER_YML).should eq true
  end
end
