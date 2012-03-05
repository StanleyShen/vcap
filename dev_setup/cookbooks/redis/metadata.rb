maintainer       "VMware"
maintainer_email "support@vmware.com"
license          "Apache 2.0"
description      "Installs/Configures Redis"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "1.0.0"

depends "ruby"
depends "cloudfoundry"
depends "deployment"

# [Hugues] we don't need runit I think
#depends "env"
#depends "runit"
