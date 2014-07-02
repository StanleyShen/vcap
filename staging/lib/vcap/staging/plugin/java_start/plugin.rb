class JavaStartPlugin < StagingPlugin

  def framework
    'java_start'
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
    "./bin/server.sh start"
  end

  def stop_command
    <<-SCRIPT
for pidfiles in #{pidfile_dir}/*.pid
do
  kill -9 $(cat $pidfiles)
done
    SCRIPT
  end

  def get_launched_process_pid
    "#{pidfile_dir}/run.pid"
  end

  def wait_for_launched_process
    <<-SCRIPT
while [ ! -f #{get_launched_process_pid} ]
do
  sleep 1
done

#{wait_for_process_terminated}
    SCRIPT
  end

  def wait_for_process_terminated
    <<-SCRIPT
pid=$(cat #{get_launched_process_pid})
while kill -0 "$pid"; do
  sleep 0.5
done
    SCRIPT
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
<%= wait_for_launched_process %>
    SCRIPT
    # TODO - ERB is pretty irritating when it comes to blank lines, such as when 'after_env_before_script' is nil.
    # There is probably a better way that doesn't involve making the above Heredoc horrible.
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  def generate_stop_script(env_vars = {})
    template = <<-SCRIPT
#!/bin/bash
DROPLET_BASE_DIR=$PWD
<%= environment_statements_for(env_vars) %>
<%= change_directory_for_start %>
<%= stop_command %>
SCRIPT
    ERB.new(template).result(binding)
  end
  
  private
  def startup_script
    vars = environment_hash
    vars['PID_FILE'] = get_launched_process_pid
    vars['APP_DIR'] = "$DROPLET_BASE_DIR/app/"
    vars['LOG_DIR'] = "$DROPLET_BASE_DIR/logs/"
    vars['JAVA_OPTS'] = "-Xmx#{application_memory}m $JAVA_OPTS"

    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def change_file_permission
    `chmod +x $PWD/app/bin/server.sh`
  end

end
