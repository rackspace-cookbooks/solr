name		 'rackspace_solr'	
maintainer       'Rackspace US, Inc.'
maintainer_email 'rackspace-cookbooks@rackspace.com'
license          'Apache 2.0'
description      'Installs/Configures Solr'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version		 '1.0.0'

supports 	 'ubuntu'

depends 'rackspace_jetty'
