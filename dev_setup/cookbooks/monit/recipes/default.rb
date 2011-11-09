#
# Cookbook Name:: stager
# Recipe:: default
#
package "monit"

# TODO: edit the /etc/monit/monitrc
# enable web-access, enable conf.d and include the vcap.monitrc generated

depends_on = Hash.new
node[:monit][:depends_on] = depends_on

#every vcap component requires nats_server if we are running it on this machine:
if !node[:monit][:daemons].nil? && node[:monit][:daemons].include?("nats_server") && !node[:monit][:vcap_components].nil?
  node[:monit][:vcap_components].each do |name|
    depends_on[name] = "depends on nats_server"
  end
end

#the dea must not be started before the service nodes are ready
#true at least in a micro-setup:
if node[:monit][:vcap_components].include?("dea")
  nodes_components = node[:monit][:vcap_components].select{|name| name =~ /_node$/}
  unless nodes_components.empty?
    dea_deps = depends_on["dea"].nil? ? [ 'depends on' ] : [ depends_on["dea"] ]
    dea_deps << nodes_components
    depends_on["dea"] = dea_deps.join(' ')
  end
end

template node[:monit][:config_file] do
  path node[:monit][:config_file]
  source "vcap.monitrc.erb"
  owner node[:deployment][:user]
  mode 0644
end

