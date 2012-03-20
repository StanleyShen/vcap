require File.expand_path('../../common', __FILE__)
require File.join(File.expand_path('../', __FILE__), 'tomcat.rb')

class JavaWebPlugin < StagingPlugin

  def framework
    'java_web'
  end

  def autostaging_template
    nil
  end

  def skip_staging webapp_root
    true
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Tomcat.prepare(destination_directory)
      copy_source_files(webapp_root)
      web_config_file = File.join(webapp_root, 'WEB-INF/web.xml')
      unless File.exist? web_config_file
        raise "Web application staging failed: web.xml not found"
      end
      services = environment[:services] if environment
      copy_service_drivers(webapp_root, services)
      Tomcat.prepare_insight destination_directory, environment, insight_agent if Tomcat.insight_bound? services
      configure_webapp(webapp_root, self.autostaging_template, environment) unless self.skip_staging(webapp_root)
      create_startup_script
      create_stop_script
    end
  end

  # The driver from which all of the staging modifications are made for Java based plugins [java_web, spring,
  # grails & lift]. Each framework plugin overrides this method to provide the implementation it needs.
  # Modifications needed by the implementations that are common to one or more plugins are provided
  # by the Tomcat class used by all of the Java based plugins. E.g are the updates for autostaging context_param,
  # autostaging servlet [both needed by 'spring' & 'grails'] & copying the autostaging jar ['spring', 'grails' &
  # 'lift'].
  def configure_webapp webapp_root, autostaging_template, environment
  end

  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  def copy_service_drivers webapp_root, services
    Tomcat.copy_service_drivers(services, webapp_root) if services
  end

  # The Tomcat start script runs from the root of the staged application.
  def change_directory_for_start
    "cd tomcat"
  end

  # We redefine this here because Tomcat doesn't want to be passed the cmdline
  # args that were given to the 'start' script.
  def start_command
    "./bin/catalina.sh run"
  end

  private

  def startup_script
    vars = environment_hash
    #vars['CATALINA_OPTS'] = configure_catalina_opts
    
    #perm_gen=`echo "$has_perm" | sed 's/-XX:MaxPermSize=/&\n/;s/.*\n//;s/m/\n&/;s/\n.*//'`
    
    generate_startup_script(vars) do
      <<-JAVA
# computes the java heap: it is the memory allocated minus the permgen and minus the extras 'fudge'
perm_gen=96 # default on 64bit jdk5
fudge=64 # the fudge factor: gc, native libs
if [ -n "$JAVA_OPTS" ]; then
  has_perm=`echo "$JAVA_OPTS" | grep -F 'XX:MaxPermSize='`
  if [ -n "$has_perm" ]; then
    perm_gen=`echo "$has_perm" | sed 's/-XX:MaxPermSize=/&\\n/;s/.*\\n//;s/m/\\n&/;s/\\n.*//'`
  fi
fi
export JVM_HEAP=`expr $[$VCAP_MEMORY/(1024*1024) - $perm_gen -$fudge]`
export CATALINA_OPTS="-Xms${JVM_HEAP}m -Xmx${JVM_HEAP}m"      
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
JAVA
    end
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end
end
