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
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default['rackspace_solr']['version'] = "3.6.2"
default['rackspace_solr']['checksum'] = "537426dcbdd0dc82dd5bf16b48b6bcaf87cb4049c1245eea8dcb79eeaf3e7ac6" #sha265
default['rackspace_solr']['directory'] = "/usr/local/src"

default['rackspace_solr']['link'] = ""
default['rackspace_solr']['download'] = ""
default['rackspace_solr']['extracted'] = ""
default['rackspace_solr']['war'] = ""

default['rackspace_solr']['home'] = "/usr/share/solr"
default['rackspace_solr']['data'] = "/usr/local/solr/data"

default['rackspace_solr']['context_path'] = '/solr'
default['rackspace_solr']['env_vars'] = {
	'solr.solr.home' => node['rackspace_solr']['home'],
	'solr.data.dir' => node['rackspace_solr']['data']
}

# SEVERE (highest value) WARNING INFO CONFIG FINE FINER FINEST (lowest value)
default['rackspace_solr']['log']['level'] = 'INFO'
default['rackspace_solr']['log']['class'] = 'java.util.logging.ConsoleHandler'
default['rackspace_solr']['log']['formatter'] = 'java.util.logging.SimpleFormatter'