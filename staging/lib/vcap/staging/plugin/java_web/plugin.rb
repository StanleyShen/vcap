class JavaWebPlugin < StagingPlugin
  def framework
    'java_web'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      change_file_permission
      create_startup_script
      create_stop_script
    end
  end

  # Sinatra has a non-standard startup process.
  # TODO - Synthesize a 'config.ru' file for each app to avoid this.
  def start_command
    "./bin/jetty.sh start"
  end
  
  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    template = <<-SCRIPT
#!/bin/bash
DROPLET_BASE_DIR=$PWD
<%= environment_statements_for(env_vars) %>
<%= after_env_before_script %>
<%= change_directory_for_start %>
(<%= start_command %>) 
    SCRIPT
    # TODO - ERB is pretty irritating when it comes to blank lines, such as when 'after_env_before_script' is nil.
    # There is probably a better way that doesn't involve making the above Heredoc horrible.
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  def generate_stop_script(env_vars = {})
    template = <<-SCRIPT
#!/bin/bash
<%= environment_statements_for(env_vars) %>
<%= stop_command %>
SCRIPT
    ERB.new(template).result(binding)
  end
  
  private
  def startup_script
    vars = environment_hash
    vars['JETTY_PID'] = "$DROPLET_BASE_DIR/run.pid"
    vars['JETTY_ARGS'] = "jetty.port=$VCAP_APP_PORT"
    #vars['JAVA_OPTIONS'] = "-Xms#{application_memory}m -Xmx#{application_memory}m"

    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def change_file_permission
    `chmod +x $PWD/app/bin/jetty.sh`
    `mv $PWD/app/modules/npn/npn-1.7.0_5.mod $PWD/app/modules/npn/npn-1.7.0_51.mod`
  end
end


