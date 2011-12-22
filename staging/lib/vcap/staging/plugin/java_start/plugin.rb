class JavaStartPlugin < StagingPlugin

  def framework
    'java_start'
  end
  
  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end
  
  def start_command
    if File.exists?("app/start_cmd.sh") || File.exists?("app/before_start.sh")
      "chmod +x start_cmd.sh; cmd=$(./start_cmd.sh -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT); $cmd"
    elsif File.exists? "app/start.jar"
      "java -jar start.jar -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    else
      "echo \"Could not find app/start_cmd.sh or app/before_start.sh or app/start.jar in #{Dir.pwd}\""
      raise "Java application staging failed: Could not find app/start_cmd.sh or app/before_start.sh or app/start.jar in #{Dir.pwd}"
    end
  end

  # Overridden in subclasses when the framework needs to start from a different directory.
  def change_directory_for_start
    if File.exists? "app/before_start.sh"
      "cd app; chmod +x before_start.sh; . ./before_start.sh -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    else
      "cd app;"
    end
  end


  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
