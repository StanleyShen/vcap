require 'rubygems'
require 'vmc'
require 'cli'
require 'zip/zip'

require 'tmpdir'
require 'uri'

require 'jobs/job'
require 'create_admin/util'
require 'create_admin/http_proxy'

module Jobs
  class UpgradeJob < Job
  end
end

class ::Jobs::UpgradeJob
  include HttpProxy

  def initialize(options)
    options = options || {}

    @app_names = options['apps']
    @data_archive_name = options['data_archive_name']
    @is_dev = options['is_dev'] || false

    @data_archive_name ||= 'data_internal.zip' if @is_dev   
    @pre_script_name = options['pre_archive_name']
    @post_script_name = options['post_archive_name']

    @version_built_name = 'version_built.properties'
    @major = options['major'] || true
  end

  def run
    init_variables
    
    num = 1
    total = 3

    begin
      at(num , total, 'Downloading...')
#      do_download()

      num = num + 1
      at(num + 1 , total, 'Unziping...')
#      do_unzip()
      
      num = num + 1
      at(num , total, 'Updating...')
      do_update()

      completed('successfully upgraded.')
    rescue Exception => e
      msg = "Failed to upgrade app: #{e.message}"
      error e
      failed( {'message' => msg, 'upgrade' => 'failed' })
    end
  end

  private
  def init_variables
    # force to refresh the manifest
    @manifest = @admin_instance.manifest(true)
    @client = @admin_instance.vmc_client()
    @admin_env = @admin_instance.app_info('admin', true)[:env]
    @app_download_path = "#{ENV['HOME']}/intalio/downloads/"
    
    if @app_names.nil?
      @apps = @admin_instance.governed_apps || 'intalio'
    else
      @apps = @app_names.split(',')
    end

    @data_archive_name = @data_archive_name || @manifest['boot_data_url'] || 'data_external.zip'
    @pre_script_name = @pre_script_name || @manifest['pre_script_url'] || 'pre.zip'
    @post_script_name = @post_script_name || @manifest['post_script_url'] || 'post.zip'

    @data_downloaded_path = @manifest['boot_data'] || "#{ENV['HOME']}/intalio/boot_data"
  end
  
  def get_repo_url
    url = CreateAdmin.get_repository_url
    return url if url && !url.empty?
    
    def_url = @admin_env['DEFAULT_DOWNLOAD_URL']
    return CreateAdmin.get_base_url(def_url)
  end
  
  def do_download()
    begin
      info "Creating download dir #{@app_download_path}"

      # application download path
#      FileUtils.rm_rf(@app_download_path) it allows to resume downloading for one specific applicaiton
      FileUtils.mkdir_p(@app_download_path)

      repo_url = get_repo_url
      recipe_apps = @manifest['recipes'].first['applications']

      app_status, ver_status, threads = {}, {}, []
      @apps.each{|app|
        recipe_app = recipe_apps.values.select{|t| t['name'] == app}.first
        # use create-distrib.tar.gz as default for compatible
        app_repo_url = recipe_app['repository']['url']
        archieve_name = app_repo_url[/([^\/]*$)/]

        app_download_url = URI(archieve_name).relative? ? URI::join(repo_url, archieve_name).to_s : archieve_name
        file_path = File.join(@app_download_path, app, app_download_url[/([^\/]*$)/])
        
        threads << Thread.new(app, file_path, app_download_url){
          # appliation archive
          app_status[app] = download(file_path, app_download_url)

          # version 
          ver_download_url = URI::join(CreateAdmin.get_base_url(app_download_url), @version_built_name).to_s
          ver_file_path = File.join(@app_download_path, app, @version_built_name)
          ver_status[app] = download(ver_file_path, ver_download_url)
        }        
      }

      # waitng all threads done
      threads.each { |t| t.join }

      # check the application download status
      raise_exception = false
      app_status.each{|k, v|        
        raise_exception = true if v['downloaded'] == false
        send_data({k => v})
      }
      raise "Download failed, please check the log for details." if raise_exception
      
      # check the version download status
      ver_status.each{|k, v|        
        raise_exception = true if v['downloaded'] == false
        send_data({k => v})
      }
      raise "Download failed, please check the log for detail message." if raise_exception

      # application download path
      FileUtils.rm_rf(@data_downloaded_path)
      FileUtils.mkdir_p(@data_downloaded_path)

      # download the data
      download_url = URI(@data_archive_name).relative? ? URI::join(repo_url, @data_archive_name).to_s : @data_archive_name
      file_path = File.join(@data_downloaded_path, download_url[/([^\/]*$)/])
      data_status = download(file_path, download_url)
      send_data(data_status)
      raise "Download failed, please check the log for detail message." if data_status['download'] == false

      if(@major)
        # pre script
        download_url = URI(@pre_script_name).relative? ? URI::join(repo_url, @pre_script_name).to_s : @pre_script_name
        file_path = File.join(@data_downloaded_path, download_url[/([^\/]*$)/])
        status = download(file_path, download_url)
        send_data(status)

        # post script
        download_url = URI(@post_script_name).relative? ? URI::join(repo_url, @post_script_name).to_s : @post_script_name
        file_path = File.join(@data_downloaded_path, download_url[/([^\/]*$)/])
        status = download(file_path, download_url)
        send_data(status)
      end
    rescue Exception => e
      error 'Failed to download apps'
      raise e
    end
  end

  def do_unzip()
    debug 'unzipping the data archive'

    data_archive = File.join(@data_downloaded_path, @data_archive_name[/([^\/]*$)/])
    if File.exists?(data_archive)
      Zip::ZipFile.open(data_archive) do |zipfile|
        zipfile.each { |f|
          zipfile.extract(f, "#{@data_downloaded_path}/#{f.name}")
        }
      end
    end

    # clean the pre and post script
    pre_target_folder = File.join(@data_downloaded_path, 'pre')
    post_target_folder = File.join(@data_downloaded_path, 'post')

    FileUtils.rm_rf(pre_target_folder)
    FileUtils.rm_rf(post_target_folder)
    @major = true
    if @major
      pre_arcive = File.join(@data_downloaded_path, @pre_script_name[/([^\/]*$)/])
      if File.exists?(pre_arcive)
        FileUtils.mkdir_p(pre_target_folder)

        Zip::ZipFile.open(pre_arcive) do |zipfile|
          zipfile.each { |f|
            zipfile.extract(f, "#{pre_target_folder}/#{f.name}") do
              true
            end
          }
        end
      end

      post_arcive = File.join(@data_downloaded_path, @post_script_name[/([^\/]*$)/])
      if File.exists?(post_arcive)
        FileUtils.mkdir_p(post_target_folder)

        Zip::ZipFile.open(post_arcive) do |zipfile|
          zipfile.each { |f|
            zipfile.extract(f, "#{post_target_folder}/#{f.name}") do
              true
            end
          }
        end
      end
    end
  end

  def do_update
    status = []
    @apps.each{|app|
      status << update(app)
    }

    raise_exception = false
    status.each {|s|
      raise_exception = true if s['updated'] == false
      send_data(s)
    }
    raise 'failed to update the application, please check the log for details' if raise_exception
  end
  
  def update(app_name)
    VMC::Cli::Config.output = STDOUT
    VMC::Cli::Config.nozip = true

    app_downloaded_path = File.join(@app_download_path, app_name)
    debug "Preparing updating #{app_name} from #{app_downloaded_path}"

    res = nil    
    begin
      upload_file, file = "#{Dir.tmpdir}/#{@appname}.zip", nil
      FileUtils.rm_f(upload_file)

      explode_dir = "#{Dir.tmpdir}/.vmc_#{@appname}_files"
      FileUtils.rm_rf(explode_dir) # Make sure we didn't have anything left over..

      Dir.chdir(app_downloaded_path) {
        # Stage the app appropriately and do the appropriate fingerprinting, etc.
        if war_file = Dir.glob('*.war').first
          debug "Exploding the war"
          VMC::Cli::ZipUtil.unpack(war_file, explode_dir)
          debug "Done Exploding the war"
        elsif war_file = Dir.glob('*.tar.gz').first
          msg = "Unpacking tar..."
          FileUtils.mkdir(explode_dir)
          system("tar -xf #{war_file} -C #{explode_dir} --strip 1")
          system("cp #{@version_built_name} #{explode_dir}/")

          debug "Done Exploding the tar"
        else
          debug "Copying the files"
          FileUtils.mkdir(explode_dir)
          files = Dir.glob('{*,.[^\.]*}')
          # Do not process .git files
          files.delete('.git') if files
          FileUtils.cp_r(files, explode_dir)
          debug "Done copying the files"
        end

        # Send the resource list to the cloudcontroller, the response will tell us what it already has..
        fingerprints = []
        total_size = 0
        debug "About to compute the fingerprints"

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

        # 4
        debug "Checking resources fingerprint..."
        # Check to see if the resource check is worth the round trip
        if (total_size > (10*1024)) # 10k for now
          # Send resource fingerprints to the cloud controller
          debug "Invoking check_resources with the fingerprints"
          appcloud_resources = check_resources(fingerprints, 3)
        end

        # 5
        debug"Processing..."
        if appcloud_resources
          # We can then delete what we do not need to send.
          appcloud_resources.each do |resource|
            FileUtils.rm_f resource[:fn]
            # adjust filenames sans the explode_dir prefix
            resource[:fn].sub!("#{explode_dir}/", '')
          end
        end

        # 6
        debug "Packing the upload bits..."
        # Perform Packing of the upload bits here.
        unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
          VMC::Cli::ZipUtil.pack(explode_dir, upload_file)

          upload_size = File.size(upload_file);
          if upload_size > 1024*1024
            upload_size  = (upload_size/(1024.0*1024.0)).round.to_s + 'M'
          elsif upload_size > 0
            upload_size  = (upload_size/1024.0).round.to_s + 'K'
          end
        else
          upload_size = '0K'
        end

        # 7
        debug "Prepare to upload"
        unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
          VMC::Cli::Command::FileWithPercentOutput.display_str = upload_str = "Uploading (#{upload_size}): "
          VMC::Cli::Command::FileWithPercentOutput.upload_size = File.size(upload_file);
          file = VMC::Cli::Command::FileWithPercentOutput.open(upload_file, 'rb')
        end

        # 8
        debug "Uploading #{app_name}..."
        upload_retry = 3;
        upload_app(app_name, file, appcloud_resources, 3)
        
        # 9
        message = "successfully update the application: #{app_name}"
        debug message
        res = {'updated' => true, 'message' => message}
      }
    rescue Exception => e
      message = "It failed to update #{app_name} due to exception: #{e.message}"
      error e
      res = {'updated' => false, 'message' => message}
    ensure
      # Cleanup if we created an exploded directory.
      FileUtils.rm_f(upload_file) if upload_file
      FileUtils.rm_rf(explode_dir) if explode_dir
    end

    res
  end

  def download(filepath, url)
    File.delete(filepath) if(File::exists?(filepath))
    # create parent directory
    FileUtils.mkdir_p(File.expand_path("..", filepath))
    debug "Start download of #{url}"

    downloaded, info = false, nil
    file = open(filepath, "wb")
    begin
      http_get(url) do |resp| 
        total_size = resp.header.content_length()
        debug "#{url} Response #{total_size} bytes, code #{resp.code}"

        count = 0
        if total_size > 0 && resp.code == "200"
          resp.read_body do |segment|
            count = count + 1
            file.write(segment)

            if(count > 1000 && !file.closed?)
                count = 0
                filesize = File.size?(filepath)
                percent = (((filesize.fdiv(total_size)) * 100)).round() if filesize

                debug "#{url} download progress #{percent}%"
            end
            info = "Download #{url} successfully"
            downloaded = true
          end
        else
          info = "Failed to download #{url}. Got response code #{resp.code}"
        end        
      end
    ensure
      file.close()
    end
    debug info

    File.delete(filepath) if(File::exists?(filepath)) && !downloaded
    {'downloaded' => downloaded, 'message' => info}
  end

  def check_resources(fingerprints, check_retry)
    begin
      @client.check_resources(fingerprints)
    rescue Exception => e
      check_retry -= 1
      if(check_retry >= 0)
        info "Retry check resources #{3-check_retry}"
        check_resources(fingerprints, check_retry)
      end
    end
  end

  def upload_app(appname, file, appcloud_resources, upload_retry)
    upload_retry -= 1
    begin
      @client.upload_app(appname, file, appcloud_resources)
    rescue VMC::Client::TargetError => te
      if te.message.index('Error (JSON 502)').nil?
        if(upload_retry >= 0)
          upload_app(appname, file, appcloud_resources, upload_retry)
        else
          error "#{te.class.name} => #{te.message}"
          error te.backtrace.inspect
          raise te
        end
      else
        warn "Ignoring 502 from vcap when uploading"
        update_info = @client.app_update_info(appname)
        since = 0 #update_info[:since].to_i
        state = update_info[:state]
        started_at = Time.now.to_i
        # If state is succeeded and elapse time is less than 10 min, wait
        # Or if state is 'UPDATING' and elaspe time is between 10 and 20 min, wait
        # Or if state is 'CANARY_FAILED' and elaspe time is less then 2 min, wait
        while(state == 'SUCCEEDED' && since <= 60 * 10 ||
          (since >= 60 * 10 && since <= 60 * 20 && state != 'UPDATING') ||
          (state == 'CANARY_FAILED' && since < 60 * 2))
          raise 'Updating application failed (CANARY_FAILED)' if (state == 'CANARY_FAILED' && since < 60 * 2)

          debug "waiting for update since #{since/60} mins => state: #{update_info[:state]}"
          sleep(60)
          update_info = @client.app_update_info(appname)
          state = update_info[:state]
          since = Time.now.to_i - started_at #update_info[:since].to_i
        end

        raise 'Unable to update application' if state != 'UPDATING'
      end
    rescue Exception => e
      error "upload_app - #{e.class.name} => #{e.message}"
      error "#{e.class.name} => #{e.message}"
      error e.backtrace.inspect
      raise e
    end
  end
end