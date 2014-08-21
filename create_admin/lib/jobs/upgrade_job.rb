require 'rubygems'
require 'vmc'
require 'cli'
require 'zip/zip'

require 'tmpdir'

require 'jobs/job'
require 'create_admin/util'
require 'create_admin/http_proxy'

module Jobs
  class UpgradeJob < Job
  end
end

class ::Jobs::UpgradeJob
  include VMC::KNIFE::Cli
  include HttpProxy

  def initialize(options)
    options = options || {}
    @appname = options['app_name'] || 'intalio'
    @archive_name = if @appname == "intalio"
      "create-distrib.tar.gz"
    else
      # TODO: need to consider other applications: central, data, jobs, intalio-sch
      "#{options['app_name']}.tar.gz"
    end

    manifest_path = options['manifest'] || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    manifest = load_manifest(@manifest_path)
    @client = vmc_client_from_manifest(manifest, true)
    @admin_env = CreateAdmin.app_info(manifest, 'admin')[:env]

    @data_archive_name = options['data_archive_name'] || 'data_external.zip'
    @is_dev = options['is_dev'] || false
    @data_archive_name ||= 'data_internal.zip' if @is_dev
    @pre_script_name = "pre.zip"
    @post_script_name = "post.zip"
    @version_built_name = "version_built.properties"

    @url = CreateAdmin.get_download_url(@admin_env['DEFAULT_DOWNLOAD_URL'])
    @download_path = "#{ENV['HOME']}/intalio/downloads/#{@appname}/"
    @major = options['major'] || true
  end

  def run
    @num = 0
    @total = 100

    begin
      at(@num , @total, { 'upgrade' => 'queued' })
      is_ok = doDownload()

      doUnzip() if is_ok
      debug "About to start update"
      doUpdate()
    rescue Exception => e
      msg = "Failed to upgrade app: #{e.message}"
      error msg
      error e.backtrace.inspect
      failed( {'message' => msg, 'upgrade' => 'failed' })
    end

  end

  private
  def doDownload()
    begin
      info "Creating download dir #{@download_path}"
      FileUtils.rm_rf(@download_path)
      FileUtils.mkdir_p(@download_path)

      info "calling net http on #{@url}"
      download_file_path = "#{@download_path}/#{@archive_name}"
      download(download_file_path, @url)

      version_built_path = "#{@download_path}/#{@version_built_name}"
      version_built_url = @url.sub(/([^\/]*\.tar\.gz)/, @version_built_name)
      download(version_built_path, version_built_url)

      bootstrap_filepath = "#{@download_path}/#{@data_archive_name}"
      bootstrap_urlpath = @url.sub(/([^\/]*\.tar\.gz)/, @data_archive_name)
      download(bootstrap_filepath, bootstrap_urlpath)

      if(@major)
        pre_script_filepath = "#{@download_path}/#{@pre_script_name}"
        pre_script_urlpath = @url.sub(/([^\/]*\.tar\.gz)/, @pre_script_name)
        download(pre_script_filepath, pre_script_urlpath, true)

        post_script_filepath = "#{@download_path}/#{@post_script_name}"
        post_script_urlpath = @url.sub(/([^\/]*\.tar\.gz)/, @post_script_name)
        download(post_script_filepath, post_script_urlpath, true)
      end
      return true
    rescue Exception => e
      msg = "Failed to download app"
      error msg
      error e.message
      error e.backtrace.inspect
      failed({:message=>msg, :upgrade=>'failed', :exception => e.message})
    end
    false
  end

  def doUnzip()

    ENV['INTALIO_BOOT_DATA'] = "#{ENV['HOME']}/test" if @is_dev
    bootstrap_home = ENV['INTALIO_BOOT_DATA'] || '/home/ubuntu/intalio/boot_data'

    unless bootstrap_home.nil? or bootstrap_home == ''
      FileUtils.rm_rf(bootstrap_home)
      FileUtils.mkdir_p(bootstrap_home)
    end

    at(inc_step(), @total, "Unzipping archive...")
    if(File.exists?("#{@download_path}/#{@data_archive_name}"))
      Zip::ZipFile.open("#{@download_path}/#{@data_archive_name}") do |zipfile|
        zipfile.each { |f|
          zipfile.extract(f, "#{bootstrap_home}/#{f.name}")
        }
      end
    end

    if(@major)
      if(File.exists?("#{@download_path}/#{@pre_script_name}"))
        FileUtils.mkdir_p("#{bootstrap_home}/pre")
        at(inc_step(), @total, "Unzipping pre script...")
        Zip::ZipFile.open("#{@download_path}/#{@pre_script_name}") do |zipfile|
          zipfile.each { |f|
            zipfile.extract(f, "#{bootstrap_home}/pre/#{f.name}") do
              true
            end
          }
        end
      end

      if(File.exists?("#{@download_path}/#{@post_script_name}"))
        FileUtils.mkdir_p("#{bootstrap_home}/post")
        at(inc_step(), @total, "Unzipping post script...")
        Zip::ZipFile.open("#{@download_path}/#{@post_script_name}") do |zipfile|
          zipfile.each { |f|
            zipfile.extract(f, "#{bootstrap_home}/post/#{f.name}") do
              true
            end
          }
        end
      end
    end

  end

  def doUpdate()
    debug "Updating #{@appname} at #{@download_path}"
    VMC::Cli::Config.output = STDOUT
    VMC::Cli::Config.nozip = true

    begin

    total = 10
    msg = "Preparing..."
    debug msg

    # 0
    @num = 50
    at(@num, @total, { 'upgrade' => 'working', :message=>msg })

    upload_file, file = "#{Dir.tmpdir}/#{@appname}.zip", nil
    FileUtils.rm_f(upload_file)

    explode_dir = "#{Dir.tmpdir}/.vmc_#{@appname}_files"    
    FileUtils.rm_rf(explode_dir) # Make sure we didn't have anything left over..

    Dir.chdir(@download_path) do
      info "In #{@download_path} performing app upgrade"
      # Stage the app appropriately and do the appropriate fingerprinting, etc.
      if war_file = Dir.glob('*.war').first
        debug "Exploding the war"

        # 1
        msg = "Unpacking..."
        at(inc_step, @total, "#{msg}")
        VMC::Cli::ZipUtil.unpack(war_file, explode_dir)
        debug "Done Exploding the war"

        # 2
        msg = "Unpacked"
        at(inc_step, @total, "#{msg}")
      elsif war_file = Dir.glob('*.tar.gz').first
        msg = "Unpacking tar..."
        FileUtils.mkdir(explode_dir)
        system("tar -xf #{war_file} -C #{explode_dir} --strip 1")
        system("cp #{@version_built_name} #{explode_dir}/")
        info "Done Exploding the tar"
        msg = "Unpacked tar"
        at(inc_step, @total, "#{msg}")
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
        info "About to compute the fingerprints"

        # 3
        msg = "Computing..."
        at(inc_step, @total, "#{msg}")

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
        msg = "Checking..."
        at(inc_step, @total, "#{msg}")
        # Check to see if the resource check is worth the round trip
        if (total_size > (10*1024)) # 10k for now
          # Send resource fingerprints to the cloud controller
          info "Invoking check_resources with the fingerprints"
          appcloud_resources = check_resources(fingerprints, 3)
        end

        # 5
        msg = "Processing..."
        at(inc_step, @total, "#{msg}")
        if appcloud_resources
          info '  Processing resources: '
          # We can then delete what we do not need to send.
          appcloud_resources.each do |resource|
            FileUtils.rm_f resource[:fn]
            # adjust filenames sans the explode_dir prefix
            resource[:fn].sub!("#{explode_dir}/", '')
          end
          info 'OK'
        end

        # 6
        msg = "Packing..."
        at(inc_step, @total, "#{msg}")

      # Perform Packing of the upload bits here.
      unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
        info '  Packing application: '
        VMC::Cli::ZipUtil.pack(explode_dir, upload_file)
        info 'OK'

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
      msg = "Prepare to upload"
      at(inc_step, @total, "#{msg}")

      upload_str = "  Uploading "
      info upload_str

      unless VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
        VMC::Cli::Command::FileWithPercentOutput.display_str = upload_str
        VMC::Cli::Command::FileWithPercentOutput.upload_size = File.size(upload_file);
        file = VMC::Cli::Command::FileWithPercentOutput.open(upload_file, 'rb')
      end
      info "client.upload_app about to start"

      # 8
      msg = "Uploading..."
      at(inc_step, @total, "#{msg}")

      upload_retry = 3;
      upload_app(@appname, file, appcloud_resources, 3)
      debug "Done client.upload_app"

      # 9
      msg = "Uploaded"
      at(inc_step, @total, "#{msg}")

      # 10
      msg = "Done"
      debug "#{msg}"
      at(95, @total, "#{msg}")

      completed(:upgrade=>'completed')
    end
  rescue Exception => e
    error "It failed to update due to below exception"
    error e.message
    error e.backtrace.inspect
    failed({:message=>"Update failed", :upgrade=> 'failed', :exception => e.message})
  ensure
    # Cleanup if we created an exploded directory.
    FileUtils.rm_f(upload_file) if upload_file
    FileUtils.rm_rf(explode_dir) if explode_dir
  end
  end

  def download(filepath, url, optional=false)
    File.delete(filepath) if(File::exists?(filepath))
    debug "Start download of #{url}"
    @count = 0
    inc_step()
    empty_target = false

    at(@num , @total, "Start download of #{url}")
    file = open(filepath, "wb")
    begin
      http_get(url) do |resp|
        content_length = resp.header.content_length()
        total_size = content_length / 1024 / 1024 unless content_length.nil?
        debug "Response #{content_length} bytes, code #{resp.code}"
        if content_length > 0 && resp.code == "200"
          at(@num , @total, {:upgrade => 'working'})
          resp.read_body do |segment|
            @count = @count + 1
            file.write(segment)
            if(@count>1000 && !file.closed?)
                @count = 0
                filesize = File.size?(filepath)
                filesize = (filesize / 1024) /1024 unless filesize.nil?

                percent = (((filesize.fdiv(total_size)) * 100)).round() unless total_size.nil? || total_size < 1
                debug "#{url} download progress #{percent}%"
                inc_step(1)
                at(@num , @total, "#{url} Downloaded #{filesize}MB")
            end              
          end
        elsif optional && resp.code == '404'
          debug "Response code #{resp.code}"
          debug "Optional package from #{url} not available"
          empty_target = true          
        else
          error "Download response code #{resp.code}"
          raise "Failed to download #{url}. Got response code #{resp.code}"
        end        
      end
    ensure
      file.close()
    end
    
    # Removes the empty file created if the target does not exists
    # This is needed in case the next download does not need this package
    # and yet its still lingering around which may cause issues when upgrading
    File.delete(filepath) if(File::exists?(filepath)) and empty_target
    at(@num , @total, "#{url} download completed")      
    debug "download completed."
  end

  def inc_step(step=5)
    @num += step unless @num >= 95
    @num
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