# Download, extract the elasticsearch libraries and binaries
#
install_path = node.elasticsearch[:exec_path]
es_tarball_path = File.join(node[:deployment][:setup_cache], "elasticsearch-#{node.elasticsearch[:version]}.tar.gz")

remote_file es_tarball_path do
  owner node[:deployment][:user]
  source node.elasticsearch[:download_url]
  not_if do
    ::File.exists?(es_tarball_path)
  end  
end

bash "Install Elasticsearch #{node.elasticsearch[:version]}" do
  user node[:deployment][:user]
  code <<-EOH
  mkdir -p #{install_path}
  tar xvzf #{es_tarball_path} -C #{install_path}  --strip-components=1
  EOH
  not_if do
    ::File.exists?(File.join(install_path, "bin", "elasticsearch"))
  end
end

# Increase open file and memory limits
#
bash "enable user limits" do
  user 'root'

  code <<-END.gsub(/^    /, '')
    echo 'session    required   pam_limits.so' >> /etc/pam.d/su
  END

  not_if { ::File.read("/etc/pam.d/su").match(/^session    required   pam_limits\.so/) }
end

file "/etc/security/limits.d/10-elasticsearch.conf" do
  content <<-END.gsub(/^    /, '')
    #{node.elasticsearch.fetch(:user, node[:deployment][:user])}     -    nofile    #{node.elasticsearch[:limits][:nofile]}
    #{node.elasticsearch.fetch(:user, node[:deployment][:user])}     -    memlock   #{node.elasticsearch[:limits][:memlock]}
  END
end