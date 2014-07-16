#
# Cookbook Name:: node
# Recipe:: default
#

cloudfoundry_service "elasticsearch" do
  components ["elasticsearch_node"]
end