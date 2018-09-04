require "../spec_helper"

module Amber::Recipes
  describe Recipe do
    recipe = "./.tmp/default"

    describe "#can_generate?" do
      Spec.before_each do
        Dir.mkdir_p("#{recipe}/app")
        Dir.mkdir_p("#{recipe}/controller")
        Dir.mkdir_p("#{recipe}/model")
        Dir.mkdir_p("#{recipe}/scaffold")
      end

      Spec.after_each do
        FileUtils.rm_rf("#{recipe}")
      end

      it "should return true for default app" do
        Recipe.can_generate?("app", recipe).should eq true
      end

      it "should return true for default controller" do
        Recipe.can_generate?("controller", recipe).should eq true
      end

      it "should return true for default model" do
        Recipe.can_generate?("model", recipe).should eq true
      end

      it "should return true for default scaffold" do
        Recipe.can_generate?("scaffold", recipe).should eq true
      end
    end
  end
end
