#
# Cookbook Name:: rackspace_solr
# Recipe:: default
#
# Copyright 2013, HipSnip Limited
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "rackspace_jetty"

require 'fileutils'

################################################################################
# Create Solr home directory

directory node['rackspace_solr']['home'] do
  owner node['rackspace_jetty']['user']
  group node['rackspace_jetty']['group']
  mode "755"
  recursive true
  action :create
end

################################################################################
# Guess few node attributes if not set based on the given solr version in
# node['rackspace_solr']['version']

if node['rackspace_solr']['link'].empty?
  if /^(?:1\.4\.(?:0|1){1}|3\.[0-9]{1,}\.[0-9]{1,})/.match(node['rackspace_solr']['version'])
    node.default['rackspace_solr']['link'] = "http://archive.apache.org/dist/lucene/solr/#{node['rackspace_solr']['version']}/apache-solr-#{node['rackspace_solr']['version']}.tgz"
    node.default['rackspace_solr']['download'] = "#{node['rackspace_solr']['directory']}/apache-solr-#{node['rackspace_solr']['version']}.tgz"
    node.default['rackspace_solr']['extracted'] = "#{node['rackspace_solr']['directory']}/apache-solr-#{node['rackspace_solr']['version']}"
    node.default['rackspace_solr']['war'] = "apache-solr-#{node['rackspace_solr']['version']}.war"
  elsif /^4\.[0-9]{1,}\.[0-9]{1,}/.match(node['rackspace_solr']['version'])
    node.default['rackspace_solr']['link'] = "http://archive.apache.org/dist/lucene/solr/#{node['rackspace_solr']['version']}/solr-#{node['rackspace_solr']['version']}.tgz"
    node.default['rackspace_solr']['download'] = "#{node['rackspace_solr']['directory']}/solr-#{node['rackspace_solr']['version']}.tgz"
    node.default['rackspace_solr']['extracted'] = "#{node['rackspace_solr']['directory']}/solr-#{node['rackspace_solr']['version']}"
    node.default['rackspace_solr']['war'] = "solr-#{node['rackspace_solr']['version']}.war"
  else
    # throw here!
  end
end

################################################################################
# Download and unpack

remote_file node['rackspace_solr']['download'] do
  source node['rackspace_solr']['link']
  checksum node['rackspace_solr']['checksum']
  mode 0644
end


ruby_block 'Extract Solr' do
  block do
    Chef::Log.info "Extracting Solr archive #{node['rackspace_solr']['download']} into #{node['rackspace_solr']['directory']}"
    `tar xzf #{node['rackspace_solr']['download']} -C #{node['rackspace_solr']['directory']}`
    raise "Failed to extract Solr package" unless File.exists?(node['rackspace_solr']['extracted'])
  end

  action :create

  not_if do
    File.exists?(node['rackspace_solr']['extracted'])
  end
end

################################################################################
# Install into Jetty

jetty_major_version = 8
if /^9.*/.match(node['rackspace_jetty']['version'])
  jetty_major_version = 9
  war_target_path = File.join(node['rackspace_jetty']['webapps'],'solr.war')
else
  war_target_path = File.join(node['rackspace_jetty']['webapps'],node['rackspace_solr']['war'])
end

ruby_block 'Copy Solr war into Jetty webapps folder' do
  block do
    Chef::Log.info "Copying #{node['rackspace_solr']['war']} to #{war_target_path}"

    FileUtils.cp(File.join(node['rackspace_solr']['extracted'],'dist',node['rackspace_solr']['war']),war_target_path)
    FileUtils.chown_R(node['rackspace_jetty']['user'],node['rackspace_jetty']['group'],war_target_path)
    raise "Failed to copy Solr war" unless File.exists?(war_target_path)
  end

  action :create
  notifies :restart, "service[jetty]"

  not_if do
    if not File.exists?(war_target_path)
      false
    else
      downloaded_signature = `sha256sum #{node['rackspace_solr']['extracted']}/dist/#{node['rackspace_solr']['war']} | cut -d ' ' -f 1`
      installed_signature = `sha256sum #{war_target_path} | cut -d ' ' -f 1`
      downloaded_signature == installed_signature
    end
  end
end

ruby_block 'Copy ext libs into Jetty' do
  block do
    lib_files = Dir.glob(File.join(node['rackspace_solr']['extracted'],'/example/lib/ext/') + '**')
    ext_dir = File.join(node['rackspace_jetty']['home'],'/lib/ext')

    Chef::Log.info "Copying #{lib_files} into #{ext_dir}"
    FileUtils.cp_r(lib_files, ext_dir)
    raise "Failed to copy ext lib files" unless !Dir.glob(File.join(ext_dir, 'log4j-*.jar')).empty?
  end

  action :create
  notifies :restart, "service[jetty]"

  not_if do
    /^4\.[1-2]{1,}\.[0-9]{1,}|^[1-3]/.match(node['rackspace_solr']['version']) ||
    !Dir.glob(File.join(node['rackspace_jetty']['home'],'/lib/ext/','log4j-*.jar')).empty?
  end
end

template "#{node['rackspace_jetty']['contexts']}/solr.xml" do
  owner node['rackspace_jetty']['user']
  group node['rackspace_jetty']['group']
  mode "644"
  source "solr.context.erb"
  notifies :restart, "service[jetty]"
  not_if { jetty_major_version > 8 }
end

directory node['rackspace_solr']['data'] do
  owner node['rackspace_jetty']['user']
  group node['rackspace_jetty']['group']
  mode "755"
  recursive true
  action :create
end

################################################################################
# Export desired Solr environment variables into the attribute node.set['jetty']['java_options']

solr_env_vars = []
for key in node['rackspace_solr']['env_vars'].keys.sort do
  solr_env_vars.push("-D#{key}=#{node['rackspace_solr']['env_vars'][key]}")
end

node.set['rackspace_jetty']['java_options'] = (node['rackspace_jetty']['java_options'] + solr_env_vars).uniq


################################################################################
# Configure

ruby_block 'Copy Solr configurations files' do
  block do
    solr_xml = node['rackspace_solr']['version'][0] == '1' ? 'conf/solrconfig.xml' : 'solr.xml'
    config_files = Dir.glob(File.join(node['rackspace_solr']['extracted'],'/example/solr/') + '**')
    Chef::Log.info "Copying #{config_files} into #{node['rackspace_solr']['home']}"
    FileUtils.cp_r(config_files, "#{node['rackspace_solr']['home']}/")
    FileUtils.chown_R(node['rackspace_jetty']['user'],node['rackspace_jetty']['group'],node['rackspace_solr']['home'])
    raise "Failed to copy Solr configurations files" unless File.exists?(File.join(node['rackspace_solr']['home'], solr_xml))
  end

  action :create
  notifies :restart, "service[jetty]"

  not_if do
    if not File.exists?(File.join(node['rackspace_solr']['home'], 'solr.xml'))
      false
    else
      downloaded_signature = `sha256sum #{node['rackspace_solr']['extracted']}/dist/#{node['rackspace_solr']['war']} | cut -d ' ' -f 1`
      installed_signature = `sha256sum #{war_target_path} | cut -d ' ' -f 1`
      downloaded_signature == installed_signature
    end
  end
end

######################################################################################
# Set log level

# directory node['rackspace_solr']['log_dir'] do
# owner node['rackspace_jetty']['user']
# group node['rackspace_jetty']['group']
# mode '755'
# end

logging_properties_file = "#{node['rackspace_jetty']['home']}/etc/logging.properties"
template logging_properties_file do
  source 'logging.properties.erb'
  mode '644'
  notifies :restart, "service[jetty]"
end

node.set['rackspace_jetty']['java_options'] = node.set['rackspace_jetty']['java_options'].push("-Djava.util.logging.config.file=#{logging_properties_file}").uniq

