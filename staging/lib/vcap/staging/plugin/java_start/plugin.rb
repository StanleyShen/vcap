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
    if File.exists? "start.jar"
      "java -jar start.jar -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    else
      "./start.sh -Xms#{application_memory}m -Xmx#{application_memory}m -Djetty.port=$VCAP_APP_PORT"
    end
  end
end
