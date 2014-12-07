class doapache (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  $group_name = 'www-data',
  $with_memcache = false,

  # by default work off the Zend Server (default) repo, options '6.0, 6.1, 6.2, 6.3'
  $server_provider = 'zend',
  $server_version = undef,
  # by default, install php 5.3, option '5.4, 5.5'
  $php_version = '5.3',
  
  # php.ini setting defaults
  $php_path = '/usr/local/zend/etc/php.ini',
  $php_timezone = 'Europe/London',
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

  # port only used for monitoring
  $port = 80,

  # end of class arguments
  # ----------------------
  # begin class

) {

  case $server_provider {
    'zend': {
      class { 'doapache::zendserver':
        user => $user,
        group_name => $group_name,
        with_memcache => $with_memcache,
        server_provider => $server_provider,
        server_version => $server_version,
        php_version => $php_version,
        notifier_dir => $notifier_dir,
      }
      # append zend user to groups
      $webserver_user_group_append = ',zend'
      # configure php for zendserver
      class {'doapache::php':
        user => $user,
        server_provider => $server_provider,
        server_version => $server_version,
        php_version => $php_version,
        php_path => $php_path,
        php_timezone => $php_timezone,
        php_memory_limit => $php_memory_limit,
        php_post_max_size => $php_post_max_size,
        php_upload_max_filesize => $php_upload_max_filesize,
        php_internal_encoding => $php_internal_encoding,
        php_session_gc_maxlifetime => $php_session_gc_maxlifetime,
        php_max_input_vars => $php_max_input_vars,
        notifier_dir => $notifier_dir,
      }
    }
    'apache': {
      # no need to append user because apache already in group add list
      $webserver_user_group_append = ''
      # use puppet module to install apache (uses yum, therefore devopera repo)
      class { 'apache':
        group => $group_name,
      }
      # create a common anchor for external packages
      anchor { 'doapache-package' :
        require => Package["${::apache::params::apache_name}"],
      }
      anchor { 'doapache-pre-start' :
        before => Service["${::apache::params::service_name}"],
      }
      case $server_version {
        '2.2.29-1': {
          # install devopera yum repo, not enabled by default
          yumrepo { 'devopera':
            baseurl  => 'http://files.devopera.com/repo/CentOS/6/x86_64/',
            enabled  => 1,
            # disable gpgcheck for now, keep it simple
            gpgcheck => 0,
            # gpgkey   => "http://files.devopera.com/repo/CentOS/6/x86_64/RPM-GPG-KEY-CentOS-6",
            descr    => "Extra Packages for Enterprise Linux 6 - \$basearch ",
            before   => [Class['apache']],
          }
          # setup additional config file that's not included in apache package
          file { 'doapache-mpm-sysconfig-httpd':
            name => '/etc/sysconfig/httpd',
            source => 'puppet:///modules/doapache/httpd-sysconfig-mpm.conf',
            owner => 'root',
            group => 'root',
            mode => 0644,
            before => [Class['apache']],
          }
          # install required apache packages
          if ! defined(Package['httpd']) {
            package { 'httpd' :
              ensure => $server_version,
              require => [Yumrepo['devopera']],
            }
          }
          if ! defined(Package['mod_ssl']) {
            package { 'mod_ssl' :
              ensure => $server_version,
              require => [Yumrepo['devopera']],
            }
          }
        }
      }
          # package { 'httpd':
          #   ensure => present,
          # }
          # # start apache server on startup
          # service { 'doapache-apache-server-startup' :
          #   name => 'httpd',
          #   enable => true,
          #   ensure => running,
          #   require => Augeas['doapache-php-ini'],
          # }
          # # create a common anchor for external packages
          # anchor { 'doapache-package' :
          #   require => Package['httpd'],
          # }
          # anchor { 'doapache-pre-start' :
          #   before => Service['doapache-apache-server-startup'],
          # }
    }
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
    class { 'doapache::monitor' : 
      port => $port, 
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

  # setup hostname in conf.d
  file { 'doapache-conf-hostname' :
    name => "/etc/${apache::params::apache_name}/conf.d/hostname.conf",
    content => "ServerName ${fqdn}\nNameVirtualHost *:${port}\n",
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

  case $operatingsystem {
    centos, redhat, fedora: {
    }
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
    }
  }

}
