require 'rubygems'
require 'vmc_knife'

require "dataservice/postgres_ds"
require "create_admin/log"


module CreateAdmin
  include ::DataService::PostgresSvc
  include ::CreateAdmin::Log
  
  def self.normalize_file_path(path)
    # absolute path
    return path if (path.start_with?(File::SEPARATOR))
    File.join(ENV['HOME'], path)
  end
  
  def self.file_metadata(file_path)
    name = File.basename(file_path)
    size = File.size(file_path)
    last_modified = File.mtime(file_path).to_i
    {'name' => name, 'size' => size, 'last_modified' => last_modified}
  end

  def self.get_file(options, name_required = false)
    type = options['type']
    path = options['path']
    name = options['name']

    if (path.nil?)
      raise 'type must be specified.' if type.nil?
      raise 'name must be specified.' if name_required && name.nil?
      case type
        when 'backup'
          path = if name
            File.join("#{ENV['HOME']}/cloudfoundry/backup", name)
          else
            "#{ENV['HOME']}/cloudfoundry/backup"
          end
        when 'cdn'
          path = if name
            File.join("#{ENV['HOME']}/intalio/cdn/resources", name)
          else
            "#{ENV['HOME']}/intalio/cdn/resources"
          end
      end
      path = normalize_file_path(path)
    else
      path = normalize_file_path(path)
    end
    path
  end
  
  def self.get_download_url(def_url)
    sql = "select io_repository_url from io_system_setting where io_active='t';"
    query(sql) {|res|
      val = result.getvalue(0, 0)
      val.nil? ? def_url : "#{val}/create-distrib.tar.gz"
    }    
  end

  # Index the urls
  # @param app_urls The list of app_urls either as an array either a string with commas.
  def self.index_urls(app_urls)
    app_urls = app_urls.split(',') if app_urls.kind_of? String
    indexed_app_urls = Hash.new
    app_urls.each do |app_url|
      if app_url =~ /\/\/([\w\.\d-]*)/
        app_url = $1
      end
      indexed_app_urls[app_url.strip] = app_url.split('.').map { |url| url.strip }
    end

    indexed_app_urls
  end
  
  # Compute the closest url selected in a list of url according to a hostname
  # @param scheme The scheme to return a URL nil to return a hostname
  # @param hostname The current hostname
  # @param indexed_urls List of urls, indexed by the method index_urls
  def self.get_closest_url(scheme, hostname, indexed_urls)
    #p "Got #{@@indexed_auth_urls}"
    return "#{DOMAIN_PREFIX}#{DEFAULT_APP_DOMAIN}" if hostname == 'localhost'
    # compute which url is the closest to the current host.
  
    curr_toks = hostname.split('.')
    url_with_best_score = nil
    bestScore = -1
    indexed_urls.each do |url,toks|
     # p "Looking at #{url} #{toks}"
      index_of_url_tok = toks.length-1
      score = 0
      curr_toks.reverse.each do |tok|
      #  p "comparing #{tok} with #{toks[index_of_url_tok]}"
        if tok == toks[index_of_url_tok]
          score += 1
        else
          break
        end
        index_of_url_tok -= 1
      end
      if score > bestScore
       # p "url_with_best_score so far: #{url}"
        url_with_best_score = url
        bestScore = score
      end
    end
    return scheme ? "#{scheme}://#{url_with_best_score}" : url_with_best_score
  end
  
  def self.get_local_ipv4
    ip = Socket.ip_address_list.detect{ |intf|
      intf.ipv4? or intf.ipv4_private? and !(intf.ipv4_loopback? or intf.ipv4_multicast?)
    }
    ip.ip_address
  end
  
  def self.uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  @@filesize_conv = {
    1024 => 'B',
    1024*1024 => 'KB',
    1024*1024*1024 => 'MB',
    1024*1024*1024*1024 => 'GB',
    1024*1024*1024*1024*1024 => 'TB',
    1024*1024*1024*1024*1024*1024 => 'PB',
    1024*1024*1024*1024*1024*1024*1024 => 'EB'
  }
  
  def self.pretty_size(size)
    size = size.to_f
    @@filesize_conv.keys.each { |mult|
      next if size >= mult
      suffix = @@filesize_conv[mult]
      return "%.2f %s" % [ size / (mult / 1024), suffix ]
    }
  end
end