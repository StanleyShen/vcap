class JavaStartPlugin < StagingPlugin

  def framework
    'java_start'
  end
  
  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      raise "java application staging failed: unable to find start.jar and start.sh" unless File.exist?("app/start.sh") || File.exist?("app/start.jar")
      create_startup_script
    end
  end

  def start_command
    if File.exists? "start.jar"
      "java -jar start.jar -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    else
      "chmod +x start.sh; ./start.sh -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    end
  end
  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
