#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

compute_derived_attributes

include_recipe 'deployment'

node[:nginx_v2][:path]    = File.join(node[:deployment][:home], "deploy", "nginx", "nginx-#{node[:nginx_v2][:version]}")
node[:nginx_v2][:log_home] = File.join(node[:deployment][:home], "log", "nginx")
node[:nginx_v2][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")
node[:lua][:plugin_source_path] = File.join(node[:cloudfoundry][:home], "router", "ext", "nginx")
node[:lua][:path]    = File.join(node[:deployment][:home], "deploy", "lua", "lua-#{node[:lua][:version]}")
node[:lua][:module_path]    = File.join(node[:lua][:path], 'lib', 'lua', node[:lua][:simple_version])

nginx_version = node[:nginx_v2][:version]
nginx_path = node[:nginx_v2][:path]
lua_version = node[:lua][:version]
lua_path = node[:lua][:path]
lua_module_path = node[:lua][:module_path]
router_path = File.join(node[:cloudfoundry][:home], "router")

case node['platform']
when "ubuntu"

  %w[ build-essential].each do |pkg|
    package pkg
  end

# don't make and reinstall nginx+lua if it was already done.
unless File.exists?(nginx_path) && File.exists?(lua_module_path) &&  File.exists?(lua_path)

  # Lua related packages
  ::FileUtils.mkdir_p node[:deployment][:setup_cache]
  lua_tarball = File.join(node[:deployment][:setup_cache], "lua-#{lua_version}.tar.gz")
  cf_remote_file lua_tarball do
    owner node[:deployment][:user]
    id node[:lua][:id]
    checksum node[:lua][:checksums][:source]
  end

  lua_cjson_tarball = File.join(node[:deployment][:setup_cache], "lua-cjson-1.0.3.tar.gz")
  cf_remote_file lua_cjson_tarball do
    owner node[:deployment][:user]
    id node[:lua][:cjson_id]
    checksum node[:lua][:checksums][:cjson_source]
  end

  # Nginx related packages
  nginx_tarball = File.join(node[:deployment][:setup_cache], "nginx-#{nginx_version}.tar.gz")
  cf_remote_file nginx_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:id]
    checksum node[:nginx_v2][:checksums][:source]
  end

  nginx_patch = File.join(node[:deployment][:setup_cache], "zero_byte_in_cstr_20120315.patch")
  cf_remote_file nginx_patch do
    owner node[:deployment][:user]
    id node[:nginx_v2][:patch_id]
    checksum node[:nginx_v2][:checksums][:patch]
  end

  pcre_tarball = File.join(node[:deployment][:setup_cache], "pcre-8.12.tar.gz")
  cf_remote_file pcre_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:pcre_id]
    checksum node[:nginx_v2][:checksums][:pcre_source]
  end

  nginx_upload_module_tarball = File.join(node[:deployment][:setup_cache], "nginx_upload_module-2.2.0.tar.gz")
  cf_remote_file nginx_upload_module_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:module_upload_id]
    checksum node[:nginx_v2][:checksums][:module_upload_source]
  end

  headers_more_tarball = File.join(node[:deployment][:setup_cache], "headers-more-v0.15rc1.tar.gz")
  cf_remote_file headers_more_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:module_headers_more_id]
    checksum node[:nginx_v2][:checksums][:module_headers_more_source]
  end

  devel_kit_tarball = File.join(node[:deployment][:setup_cache], "devel-kit-v0.2.17rc2.tar.gz")
  cf_remote_file devel_kit_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:module_devel_kit_id]
    checksum node[:nginx_v2][:checksums][:module_devel_kit_source]
  end

  nginx_lua_tarball = File.join(node[:deployment][:setup_cache], "nginx-lua.v0.3.1rc24.tar.gz")
  cf_remote_file nginx_lua_tarball do
    owner node[:deployment][:user]
    id node[:nginx_v2][:module_lua_id]
    checksum node[:nginx_v2][:checksums][:module_lua_source]
  end

  directory nginx_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  directory node[:nginx_v2][:log_home] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  directory lua_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  bash "Install lua" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf #{lua_tarball}
      cd lua-#{lua_version}
      make linux install INSTALL_TOP=#{lua_path}
    EOH
  end

  bash "Install lua json" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf #{lua_cjson_tarball}
      cd lua-cjson-1.0.3
      sed 's!^PREFIX ?=.*!PREFIX ?='#{lua_path}'!' Makefile > tmp
      mv tmp Makefile
      make
      make install
    EOH
  end

  bash "Install nginx" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf #{nginx_tarball}
      tar xzf #{pcre_tarball}
      tar xzf #{nginx_upload_module_tarball}
      tar xzf #{headers_more_tarball}
      tar xzf #{devel_kit_tarball}
      tar xzf #{nginx_lua_tarball}

      [ -d chunkin-nginx-module ] && rm -rf chunkin-nginx-module
      git clone https://github.com/agentzh/chunkin-nginx-module.git --depth 1

      cd nginx-#{nginx_version}
      patch -p0 < #{nginx_patch}

      LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
        --prefix=#{nginx_path} \
        --with-pcre=../pcre-8.12 \
        --with-cc-opt=-Wno-unused-but-set-variable \
        --with-http_ssl_module \
        --add-module=../chunkin-nginx-module \
        --add-module=../nginx_upload_module-2.2.0 \
        --add-module=../headers-more-v0.15rc1 \
        --add-module=../simpl-ngx_devel_kit-bc97eea \
        --add-module=../chaoslawful-lua-nginx-module-4d92cb1

      make
      make install
    EOH
  end

end # don't make and reinstall nginx+lua if it was already done.

  git router_path do
    repository node[:cloudfoundry][:git][:router][:repo]
    revision node[:cloudfoundry][:git][:router][:branch]
    depth 1
    action :sync
    user node[:deployment][:user]
    group node[:deployment][:group]
  end

  template "uls.lua" do
    path File.join(lua_module_path, "uls.lua")
    source File.join(node[:lua][:plugin_source_path], "uls.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "tablesave.lua" do
    path File.join(lua_module_path, "tablesave.lua")
    source File.join(node[:lua][:plugin_source_path], "tablesave.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_router.conf" do
    path File.join(nginx_path, "conf", "nginx_router.conf")
    source "router-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_router" do
    path File.join("", "etc", "init.d", "nginx_router")
    source "router-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

# For now we don't do the nginx_cc and nginx_sds
=begin
  template "nginx_cc.conf" do
    path File.join(nginx_path, "conf", "nginx_cc.conf")
    source "cc-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_cc" do
    path File.join("", "etc", "init.d", "nginx_cc")
    source "cc-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  template "nginx_sds.conf" do
    path File.join(nginx_path, "conf", "nginx_sds.conf")
    source "sds-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_sds" do
    path File.join("", "etc", "init.d", "nginx_sds")
    source "sds-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end
=end

  bash "Stop running nginx" do
    code <<-EOH
      pid=`ps -ef | grep nginx | grep -v grep | awk '{print $2}'`
      [ ! -z "$pid" ] && sudo kill $pid || true
    EOH
  end

  bash "Migrate from the old router + nginx to the new one." do
    code <<-EOH
      if [ -h "#{node[:cloudfoundry][:path]}/router" ]; then
        rm "#{node[:cloudfoundry][:path]}/router"
      fi
      if [ -d "#{node[:cloudfoundry][:path]}/router" ]; then
        if [ -d "#{node[:cloudfoundry][:path]}/router_old" ]; then
          rm -rf "#{node[:cloudfoundry][:path]}/router_old"
        fi
        mv "#{node[:cloudfoundry][:path]}/router" "#{node[:cloudfoundry][:path]}/router_old"
      fi
      ln -s "#{router_path}" "#{node[:cloudfoundry][:path]}/router"
      chown node[:deployment][:user]:node[:deployment][:group] "#{node[:cloudfoundry][:path]}/router"
      if [ -x "/etc/init.d/nginx" ]; then
        chmod -x "/etc/init.d/nginx"
        mv "/etc/init.d/nginx" "/etc/init.d/nginx_disabled"
      fi
    EOH
  end

  cf_bundle_install(File.expand_path(router_path))

  service "nginx_router" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

# For now we don't do nginx_cc and nginx_sds
=begin
  service "nginx_cc" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

  service "nginx_sds" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end
=end

else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
