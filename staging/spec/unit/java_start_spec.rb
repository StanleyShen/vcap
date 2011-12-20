require 'spec_helper'
require 'fileutils'

describe "A Java start application being staged without a start.jar and start.sh" do
  before do
    app_fixture :java_start_no_start
  end

  it "should fail" do
    lambda { stage :java_start }.should raise_error
  end
end

describe "A Java start with start.jar application being staged " do
  before(:all) do
    app_fixture :java_start_jar
  end

  it "should contain a startup file that is not empty" do
    stage :java_start do |staged_dir, source_dir|
      source_app_files = Dir.glob("#{source_dir}/**/*", File::FNM_DOTMATCH)
      File.exists?(File.join(staged_dir, "app", "start.jar")).should
      File.exists?(File.join(staged_dir, "startup")).should
      File.size(File.join(staged_dir, "startup")).size.should > 7
    end
  end

end

