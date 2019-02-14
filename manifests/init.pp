class doapache (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  $group_name = 'www-data',
  $with_memcache = false,

  # by default work off the Zend Server (default) repo, options '6.0, 6.1, 6.2, 6.3'
  $server_provider = $doapache::params::server_provider,
  $zend_server_version = $doapache::params::zend_server_version,
  $apache_server_version = $doapache::params::apache_server_version,
  $php_version = $doapache::params::php_version,
  
  # php.ini setting defaults
  $apache_php_path = $doapache::params::apache_php_path,
  $zend_php_path = $doapache::params::zend_php_path,
  $php_timezone = $doapache::params::timezone,
  $php_memory_limit = '128M',
  $php_post_max_size = '10M',
  $php_upload_max_filesize = '10M',
  $php_internal_encoding = 'UTF-8',
  $php_session_gc_maxlifetime = '1440',
  $php_max_input_vars = '1000',

  # notifier dir for avoid repeat-runs
  $notifier_dir = '/etc/puppet/tmp',

  # open up firewall ports
  $firewall = true,
  # but don't monitor because we typically do that 1 layer up for web services
  $monitor = false,

  # port used for monitor/firewall/namevirtualhost
  $port = 80,
  $port_https = undef,
  # addr used by hostname.conf:NameVirtualHost as scope
  $addr = '*',

  # end of class arguments
  # ----------------------
  # begin class

) inherits doapache::params {

  include "apache::params"

  case $server_provider {
    'zend': {
      class { 'doapache::zendserver':
        user => $user,
        group_name => $group_name,
        with_memcache => $with_memcache,
        server_provider => $server_provider,
        server_version => $zend_server_version,
        php_version => $php_version,
        notifier_dir => $notifier_dir,
      }
      # append zend user to groups
      $webserver_user_group_append = ',zend'
    }
    'apache': {
      # no need to append user because apache already in group add list
      $webserver_user_group_append = ''
      # fix /etc/httpd/run symlink to be consistent with /etc/init.d/httpd pidfile location
      file { "${::apache::params::httpd_dir}/run":
        ensure  => symlink,
        target => "../..${::apache::params::logroot}",
        notify  => Service["${::apache::params::service_name}"],
        require => Package["${::apache::params::apache_name}"],
      }
      # create a common anchor for external packages
      anchor { 'doapache-package' :
        require => Package["${::apache::params::apache_name}"],
      }
      anchor { 'doapache-pre-start' :
        before => Service["${::apache::params::service_name}"],
      }
      case $apache_server_version {
        '2.2.29-1': {
          # install devopera yum repo, not enabled by default
          yumrepo { 'devopera':
            baseurl  => 'http://files.devopera.com/repo/CentOS/6/x86_64/',
            enabled  => 1,
            # disable gpgcheck for now, keep it simple
            gpgcheck => 0,
            # gpgkey   => "http://files.devopera.com/repo/CentOS/6/x86_64/RPM-GPG-KEY-CentOS-6",
            descr    => "Extra Packages for Enterprise Linux 6 - \$basearch ",
            before   => [Package["${::apache::params::apache_name}"], Package['mod_ssl']],
          }
          # setup additional config file that's not included in apache package
          file { 'doapache-mpm-sysconfig-httpd':
            name => '/etc/sysconfig/httpd',
            source => 'puppet:///modules/doapache/httpd-sysconfig-mpm.conf',
            owner => 'root',
            group => 'root',
            mode => 0644,
            before => [Package["${::apache::params::apache_name}"]],
          }
        }
        default, 'present': {
        }
      }
      # install required apache packages (to version if specified)
      if ! defined(Package["${::apache::params::apache_name}"]) {
        package { "${::apache::params::apache_name}" :
          ensure => $apache_server_version ? {
            undef   => 'present',
            default => $apache_server_version,
          },
        }
      }
      if ! defined(Package['mod_ssl']) {
        package { 'mod_ssl' :
          ensure => $apache_server_version ? {
            undef   => 'present',
            default => $apache_server_version,
          },
        }
      }
      # ensure the conf.d directory is there
      file { "${::apache::params::confd_dir}":
        ensure  => directory,
        notify  => Service["${::apache::params::service_name}"],
        require => Package["${::apache::params::apache_name}"],
      }
      service { "${::apache::params::service_name}" :
        enable => true,
        ensure => running,
        hasstatus => true,
        hasrestart => true,
      }
    }
  }

  # configure php for zendserver
  class {'doapache::php':
    user => $user,
    server_provider => $server_provider,
    php_version => $php_version,
    php_path => $server_provider ? {
      'zend' => $zend_php_path,
      'apache' => $apache_php_path,
    },
    php_timezone => $php_timezone,
    php_memory_limit => $php_memory_limit,
    php_post_max_size => $php_post_max_size,
    php_upload_max_filesize => $php_upload_max_filesize,
    php_internal_encoding => $php_internal_encoding,
    php_session_gc_maxlifetime => $php_session_gc_maxlifetime,
    php_max_input_vars => $php_max_input_vars,
    notifier_dir => $notifier_dir,
  }

  # give apache a custom group
  class {'doapache::group':
    user => $user,
    group_name => $group_name,
    notifier_dir => $notifier_dir,
  }

  #
  # SHARED section
  # Common to all web server providers
  #

  # open up firewall ports and monitor
  if ($firewall) {
    class { 'doapache::firewall' :
      port => $port,
    }
  }
  if ($monitor) {
    # trying in class because defaults don't apply to nested classes
    #class { 'doapache::monitor' : 
    #  port => $port,
    #}
    @nagios::service { "http:${port}-doapache-${::fqdn}":
      check_command => "http_port!${port}",
    }
  }

  # if we've got a message of the day, include
  @domotd::register { "Apache(${port})" : }
  
  # install memcache if set
  if ($with_memcache == true) {
    if ! defined(Package['memcached']) {
      package { 'memcached' : ensure => 'present' }
    }
    # start memcached on startup
    service { 'doapache-memcache-startup' :
      name => 'memcached',
      enable => true,
      ensure => running,
      require => [Anchor['doapache-package'], Package['memcached']],
    }
  }

  case $operatingsystem {
    ubuntu, debian: {
      # setup symlink for logs directory
      file { 'doapache-ubuntu-symlink-logs' :
        name => "${apache::params::httpd_dir}/logs",
        ensure => 'link',
        target => "${apache::params::logroot}",
        require => Anchor['doapache-package'],
      }
      # disable apache's default site
      exec { 'doapache-ubuntu-disable-default' :
        path => '/bin:/usr/bin:/sbin:/usr/sbin',
        command => 'a2dissite 000-default',
        require => Anchor['doapache-package'],
      }
      # enable mod_ssl by default
      exec { 'doapache-ubuntu-enable-modssl' :
        path => '/bin:/usr/bin:/sbin:/usr/sbin',
        command => 'a2enmod ssl',
        require => Anchor['doapache-package'],
      }
      # ensure that there's an apache user (otherwise tries to run with www-data:www-data)
      docommon::ensureuser { 'doapache-apache-create-user' :
        user => 'apache',
        home => '/var/www',
        before => [Anchor['doapache-pre-start']],
      }
    }
  }

  # flag apache as one of the sensitve services
  Service <| title == "${::apache::params::service_name}" |> {
    tag => 'service-sensitive',
  }

  # setup hostname in conf.d, with options for multiple HTTP and HTTPS virtualhosts
  file { 'doapache-conf-hostname' :
    name => "/etc/${apache::params::apache_name}/${doapache::params::confd_name}/hostname.conf",
    content => "ServerName ${fqdn}\nNameVirtualHost ${addr}:${port}\nNameVirtualHost ${addr}:443\n",
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

  # create simple index.html to avoid giving away sensitive details (OS/Apache)
  file { 'doapache-var-www-html-index' :
    name => '/var/www/html/index.html',
    content => "Inactive (Server IP: ${::ipaddress})",
    require => Anchor['doapache-package'],
  }
}
