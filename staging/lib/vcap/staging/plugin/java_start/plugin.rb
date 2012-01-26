class JavaStartPlugin < StagingPlugin

  def framework
    'java_start'
  end
  
  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      execute_custom_staging
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
      ls_echo=`ls -la app`
      raise "Java application staging failed: Could not find app/start_cmd.sh or app/before_start.sh or app/start.jar in #{Dir.pwd}; here is what is there: #{ls_echo}"
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

  # Override the original method to cope with the case where a root folder
  # is the content of the zip. java_start will copy the content of the root folder.
  # disregard META-INF as such a folder in case the zip was created as a jar.
  def copy_source_files(dest = nil)
    dest ||= File.join(destination_directory, 'app')
    # if there is a single folder let's actually copy its content.
    at_least_one_file = false
    at_least_two_folders = false
    src_folder=nil
    Dir.chdir(source_directory) do
      Dir.new(".").each do |filename|
        if File.directory? filename
          if filename != "." && filename != ".." && filename != "META-INF"
            if src_folder.nil?
              src_folder = filename
            else
              at_least_two_folders = true
            end
          end
        else
          at_least_one_file = true
        end
      end
    end
    if at_least_two_folders || at_least_one_file || src_folder.nil?
      #this is the default behavior
      system "cp -a #{File.join(source_directory, "*")} #{dest}"
    else
      system "cp -a #{File.join(source_directory, src_folder, "*")} #{dest}"
    end
  end
  
  def execute_custom_staging
    if File.exists?("app/stage.sh")
      
      `chmod +x app/stage.sh;`
      `cd app; ./stage.sh >> ../logs/staging.log 2>&1`
      #stream the std ios to us so we can keep watching the process:
=begin      begin
        PTY.spawn("./stage.sh") do |stdin,stdout,pid|
          begin
            stdin.each do |line|
              puts line
            end
          rescue Errno::EIO
            #done
          end
        end
      rescue PTY::ChildExited
        puts "Done staging"
      end
=end
    end
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
