
# convenience variables
ruby_version = node[:ruby][:version]
ruby_source = node[:ruby][:source]
ruby_path = node[:ruby][:path]


cf_ruby_install(ruby_version, ruby_source, ruby_path)

bash "Patch url to support underscore" do
  user node[:deployment][:user]
  group node[:deployment][:group]
  
  code <<-EOH
    cd "#{node[:ruby][:path]}/lib/ruby/1.9.1/uri"
    sed -i 's/ret\\\[:HOSTNAME\\\] = hostname = "(?:\\\[a-zA-Z0-9\\\\-.\\\]|%\\\\h\\\\h)+"/ret\\\[:HOSTNAME\\\] = hostname = "(?:\\\[a-zA-Z0-9\\\\-._~\\\]|%\\\\h\\\\h)+"/g' common.rb
  EOH
end