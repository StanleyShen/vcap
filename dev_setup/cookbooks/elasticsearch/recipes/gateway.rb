#
# Cookbook Name:: gateway
# Recipe:: default
#

cloudfoundry_service "elasticsearch" do
  components ["elasticsearch_gateway"]
end