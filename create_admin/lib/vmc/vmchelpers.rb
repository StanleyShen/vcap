require 'rubygems'
require 'vmc'
require 'cli'

require 'create_admin/log'

# Adds a setter for the cli-client, target url, auth_token.
module VMC::Cli::Command
  class Base
    def client=(client)
      @client=client
    end
    def target_url=(target_url)
      @target_url=target_url
    end
    def options
      @options
    end
  end
end


#TODO; this is the same module than vmc's core_ext.rb
#If we use a new module name... it does not work as expected in the admin app?
module VMCExtensions

  #overrides:
#  def say(message)
#    #puts message
#  end
#  def display(message, nl=true)
#    puts message
#  end

  #additions:
  def wrap_json_in_textarea(object)
    "<textarea rows=\"25\" cols=\"80\">#{JSON.pretty_generate(object, JSON::PRETTY_STATE_PROTOTYPE.dup)}</textarea>"
  end

  # Returns the vmc client object from a hash or a hash serialized in json
  # If the auth_token is not passed, attempt to login.
  def client_from_json(vmc_conn_json_or_hash,login_if_necessary=true)
    unless vmc_conn_json_or_hash.kind_of? Hash
      vmc_conn = JSON.parse vmc_conn_json_or_hash
      raise "Unexpected object #{vmc_conn_json_or_hash.inspect} it should be a Hash or a JSON-hash" unless vmc_conn.kind_of? Hash
    else
      vmc_conn = vmc_conn_json_or_hash
    end
    target = vmc_conn[:target]||vmc_conn["target"]
    auth_token = vmc_conn[:auth_token]||vmc_conn["auth_token"]
    puts "targgt URI #{URI.parse target}"
    begin
      URI.parse target
    rescue
      raise "The target #{target} must point to a URL."
    end
    puts "Preparing VMC client"
    if auth_token.nil?
      puts "Creating new CF client"
      user = vmc_conn[:user]
      password = vmc_conn[:password]||vmc_conn["password"]
      raise "The user must be not nil" if user.nil?
      raise "The password must be passed when the auth_token is nil" if password.nil?
      client = VMC::Client.new(target)
      client.login(user,password) if login_if_necessary
    else
      puts "Using existing CF client"
      client = VMC::Client.new(target,auth_token)
    end
    puts "Connected to CF"
    client
  end

  # Return a vmc client as a json hash
  # This hash does not contain the password unless it is explicitly pass as a parameter here.
  def client_to_json(client,password=nil)
    res = Hash.new
    res[:target] = client.target
    res[:user] = client.user
    res[:auth_token] = client.auth_token unless client.auth_token.nil?
    res[:password] = password unless password.nil?
    res.to_json
  end

  # Returns the app hash stored in the given vmc client object.
  # Raises an exception if there is no app with this name.
  def get_app(client,name)
    app = client.app_info(name)
    raise "No application called #{name} is deployed." if app.nil?
    app
  end

  def display_logfile(path, content, instance='0', banner=nil)
    result = ''
    banner ||= "====> #{path} <====\n\n"
    if content && !content.empty?
      result += banner
      prefix = "[#{instance}: #{path}] -"#.bold # if @options[:prefixlogs]
      unless prefix
        result += content + "<br/>\n"
      else
        lines = content.split("\n")
        lines.each { |line| result += "#{prefix} #{line}<br/>\n"}
      end
      result += "<br/>\n"
    end
    result
  end

  def log_file_paths
    %w[logs/stderr.log logs/stdout.log logs/startup.log]
  end

  def grab_all_logs(client, appname)
    instances_info_envelope = client.app_instances(appname)
    return if instances_info_envelope.is_a?(Array)
    instances_info = instances_info_envelope[:instances] || []
    log_content = []
    instances_info.each do |entry|
      log_content.push(grab_logs(client, appname, entry[:index]))
    end
    log_content
  end

  def grab_logs(client, appname, instance)
    content = ''
    log_file_paths.each do |path|
      begin
        content += client.app_files(appname, path, instance)
      rescue
      end
      #display_logfile(path, content, instance)
    end
    content
  end

  def display_logfile(path, content, instance='0', banner=nil)
    banner ||= "====> #{path} <====\n\n"
    if content && !content.empty?
      display banner
      prefix = "[#{instance}: #{path}] -".bold #if @options[:prefixlogs]
      unless prefix
        display content
      else
        lines = content.split("\n")
        lines.each { |line| display "#{prefix} #{line}"}
      end
      display ''
    end
  end

  # Returns the vmc client object stored in the session. nil if no such thing
  # When the name of the cloud is not specified, use 'dev'
  def get_client(session,cloud='dev')
    clients=session[:vmc_clients]
    return clients[cloud] unless clients.nil?
  end

  def environment_add(client, appname, k, v=nil)
    app = client.app_info(appname)
    env = app[:env] || []
    k,v = k.split('=', 2) unless v
    env << "#{k}=#{v}"
    puts "Adding Environment Variable [#{k}=#{v}]..."
    app[:env] = env
    client.update_app(appname, app)
    puts 'OK'
    puts "Warn: no restart supported at this point" if app[:state] == 'STARTED'
  #  restart appname if app[:state] == 'STARTED'
  end

  # Return the value of an environment variable
  def environment_get(client, appname, variable)
    app = client.app_info(appname)
    env = app[:env]
    return nil if env.nil?
    env.each do |e|
      k,v = e.split('=')
      #puts "#{k}==?==#{v}"
      if (k == variable)
        #puts "#{k}=#{v}"
        return v
      end
    end
    return nil
  end

  def environment_del(client, appname, variable)
    app = client.app_info(appname)
    env = app[:env] || []
    deleted_env = nil
    env.each do |e|
      k,v = e.split('=')
      if (k == variable)
        deleted_env = e
        break;
      end
    end
    puts "Deleting Environment Variable [#{variable}]..."
    if deleted_env
      env.delete(deleted_env)
      app[:env] = env
      client.update_app(appname, app)
      puts 'OK'
      puts "Warn: no restart supported at this point" if app[:state] == 'STARTED'
  #    restart appname if app[:state] == 'STARTED'
    else
      puts 'OK'
    end
  end

  def environment_set(client, appname, k, v=nil)
    #if the env variable exist, delete it first
    environment_del(client,appname,k)
    #create this environment variable unless the value is empty.
    environment_add(client,appname,k,v) unless v.nil? or v.strip.empty?
  end

  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      when size == 1
        "1 Byte"
      when size < KILO_SIZE
        "%d Bytes" % size
      when size < MEGA_SIZE
        "%.#{precision}f KB" % (size / KILO_SIZE)
      when size < GIGA_SIZE
        "%.#{precision}f MB" % (size / MEGA_SIZE)
      else "%.#{precision}f GB" % (size / GIGA_SIZE)
    end
  end

  ##########debugging
  def __upload_app_bits(client,appname, path)
      display 'Uploading Application:'

      upload_file, file = "#{Dir.tmpdir}/#{appname}.zip", nil
      FileUtils.rm_f(upload_file)

      explode_dir = "#{Dir.tmpdir}/.vmc_#{appname}_files"
      FileUtils.rm_rf(explode_dir) # Make sure we didn't have anything left over..

      Dir.chdir(path) do
        # Stage the app appropriately and do the appropriate fingerprinting, etc.
        if war_file = Dir.glob('*.war').first
puts "Exploding the war"
          VMC::Cli::ZipUtil.unpack(war_file, explode_dir)
puts "Done Exploding the war"
        else
puts "Copying the files"
          FileUtils.mkdir(explode_dir)
          files = Dir.glob('{*,.[^\.]*}')
          # Do not process .git files
          files.delete('.git') if files
          FileUtils.cp_r(files, explode_dir)
puts "Done copying the files"
        end

        # Send the resource list to the cloudcontroller, the response will tell us what it already has..
###        unless @options[:noresources]
          display '  Checking for available resources: ', false
          fingerprints = []
          total_size = 0
puts "About to compute the fingerprints"
          resource_files = Dir.glob("#{explode_dir}/**/*", File::FNM_DOTMATCH)
          resource_files.each do |filename|
            next if (File.directory?(filename) || !File.exists?(filename))
            fingerprints << {
              :size => File.size(filename),
              :sha1 => Digest::SHA1.file(filename).hexdigest,
              :fn => filename
            }
            total_size += File.size(filename)
          end
puts "Finished computing the fingerprints"
          # Check to see if the resource check is worth the round trip
          if (total_size > (64*1024)) # 64k for now
            # Send resource fingerprints to the cloud controller
puts "Invoking check_resources with the fingerprints"
            appcloud_resources = client.check_resources(fingerprints)
          end
          display 'OK'.green

          if appcloud_resources
            display '  Processing resources: ', false
            # We can then delete what we do not need to send.
            appcloud_resources.each do |resource|
              FileUtils.rm_f resource[:fn]
              # adjust filenames sans the explode_dir prefix
              resource[:fn].sub!("#{explode_dir}/", '')
            end
            display 'OK'.green
          end

###        end

        # Perform Packing of the upload bits here.
        unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
          display '  Packing application: ', false
          VMC::Cli::ZipUtil.pack(explode_dir, upload_file)
          display 'OK'.green

          upload_size = File.size(upload_file);
          if upload_size > 1024*1024
            upload_size  = (upload_size/(1024.0*1024.0)).round.to_s + 'M'
          elsif upload_size > 0
            upload_size  = (upload_size/1024.0).round.to_s + 'K'
          end
        else
          upload_size = '0K'
        end

        upload_str = "  Uploading (#{upload_size}): "
        display upload_str, false

        unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
          VMC::Cli::Command::FileWithPercentOutput.display_str = upload_str
          VMC::Cli::Command::FileWithPercentOutput.upload_size = File.size(upload_file);
          file = VMC::Cli::Command::FileWithPercentOutput.open(upload_file, 'rb')
        end
puts "client.upload_app about to start"
        client.upload_app(appname, file, appcloud_resources)
puts "Done client.upload_app"
        display 'OK'.green if VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?

        display 'Push Status: ', false
        display 'OK'.green
      end

    ensure
      # Cleanup if we created an exploded directory.
      FileUtils.rm_f(upload_file) if upload_file
      FileUtils.rm_rf(explode_dir) if explode_dir
    end

######### debugging ########


end

#
#module VMCEnabler
#  include ::CreateAdmin::Log
#
#  @vmc_client
#
#  def get_vmc_client(renew=false)
#    begin
#      debug "Getting vmc client"
#      @vmc_client = login_default() if @vmc_client.nil? or renew
#      @vmc_client
#    rescue => e
#      error "Unable to login #{e.message}"
#      error e.backtrace
#      nil
#      #return { :success => false, :message => "Unable to login", :exception => e }.to_json
#    end
#
#  end
#
#  def login_default()
#    debug "Attempting vmc login"
#    @creds=Hash.new
#    @creds[:target]=ENV['cf_target']
#    @creds[:user]=ENV['cf_user']||"system@intalio.com"
#    @creds[:password]=ENV['cf_password']||"gold"
#    client = VMC::Client.new(@creds[:target])
#    #debug "login in: #{@creds[:user]},#{@creds[:password]} on #{@creds[:target]}"
#    client.login(@creds[:user],@creds[:password])
#    client
#  end
#
#end
