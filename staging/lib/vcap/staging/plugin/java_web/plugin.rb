class JavaWebPlugin < StagingPlugin
  def framework
    'java_web'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      change_file_permission
      modify_files
      create_startup_script
      create_stop_script
    end
  end

  # Sinatra has a non-standard startup process.
  # TODO - Synthesize a 'config.ru' file for each app to avoid this.
  def start_command
    "./bin/jetty.sh run"
  end

  def get_launched_process_pid
    "STARTED=$!"
  end

  def wait_for_launched_process
    "wait $STARTED"
  end
  
  def pidfile_dir
    "$DROPLET_BASE_DIR"
  end

  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    template = <<-SCRIPT
#!/bin/bash
DROPLET_BASE_DIR=$PWD
<%= environment_statements_for(env_vars) %>
<%= after_env_before_script %>
<%= change_directory_for_start %>
(<%= start_command %>) > $DROPLET_BASE_DIR/logs/stdout.log 2> $DROPLET_BASE_DIR/logs/stderr.log &
<%= get_launched_process_pid %>
echo "$STARTED" >> #{pidfile_dir}/run.pid
<%= wait_for_launched_process %>
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
    vars['JETTY_PID'] = "$DROPLET_BASE_DIR/jetty.pid"
    vars['JETTY_ARGS'] = "jetty.port=$VCAP_APP_PORT -Dlogback.appender=FILE_CF $JAVA_OPTS"

    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def change_file_permission
    `chmod +x $PWD/app/bin/jetty.sh`
  end

  def modify_files
    `sed -i -e s/Xmx.*$/Xmx#{application_memory}m/ $PWD/app/start.ini`
  end
end


