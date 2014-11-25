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

  # strip period from php version to get lib name
  $php_version_safe = regsubst($php_version, '\.', '')

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
    }
    'apache': {
      case $server_version {
        '2.2.29': {
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
        }
      }
      class { 'apache': }
      class { 'apache::mod::php':
        package_name => "php${php_version_safe}-php",
        path         => "${::apache::params::lib_path}/libphp${php_version_safe}-php5.so",
      }
      # create a common anchor for external packages
      anchor { 'doapache-package' :
        require => Package["${::apache::params::apache_name}"],
      }
      anchor { 'doapache-pre-start' :
        before => Service["${::apache::params::service_name}"],
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
  
  # tweak settings in php.ini [Main section]
  augeas { 'doapache-php-ini' :
    context => "/files${php_path}/PHP",
    changes => [
      "set date.timezone ${php_timezone}",
      "set max_input_vars ${php_max_input_vars}",
      "set memory_limit ${php_memory_limit}",
      "set post_max_size ${php_post_max_size}",
      "set upload_max_filesize ${php_upload_max_filesize}",
      "set mbstring.internal_encoding ${php_internal_encoding}",
      "set apc.rfc1867 1", # enable the display of upload progress
    ],
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

  # tweak settings in php.ini [Session section]
  augeas { 'doapache-php-ini-session' :
    context => "/files${php_path}/Session",
    changes => [
      "set session.gc_maxlifetime ${php_session_gc_maxlifetime}",
    ],
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

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

  # modify apache conf file (after apache module) to use our web $group_name and turn off ServerSignature
  $signatureSed = "-e 's/ServerSignature On/ServerSignature Off/'"
  case $operatingsystem {
    centos, redhat, fedora: {
      $apache_conf_command = "sed -i -e 's/Group apache/Group ${group_name}/' ${signatureSed} ${apache::params::conf_dir}/${apache::params::conf_file}"
      $apache_conf_if = "grep -c 'Group apache' ${apache::params::conf_dir}/${apache::params::conf_file}"
      $apache_member_list = "${user},apache,zend"
    }
    ubuntu, debian: {
      # not the www-data string here is used because we're substituting what ubuntu inserts with our var $group_name
      $apache_conf_command = "sed -i -e 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=${group_name}/' ${signatureSed} /etc/${apache::params::apache_name}/envvars"
      $apache_conf_if = "grep -c 'APACHE_RUN_GROUP=www-data' /etc/${apache::params::apache_name}/envvars"
      # ubuntu doesn't have an apache user, only www-data
      $apache_member_list = "${user},zend"
    }
  }
  exec { 'doapache-web-group-hack' :
    path => '/usr/bin:/bin:/sbin',
    command => "$apache_conf_command",
    # testing without onlyif statement, because sed should only replace if found
    # onlyif  => $apache_conf_if,
    require => Anchor['doapache-package'],
  }->
  # create www-data group and give web/zend access to it
  exec { 'doapache-user-group-add' :
    path => '/usr/bin:/usr/sbin',
    command => "groupadd -f ${group_name} -g 5000 && gpasswd -M ${apache_member_list} ${group_name}",
    before => Anchor['doapache-pre-start'],
  }->
  # apply www-data group to web root folder
  exec { 'doapache-group-apply-to-web' :
    path => '/bin:/sbin:/usr/bin:/usr/sbin',
    command => "chgrp ${group_name} -R /var/www",
    before => Anchor['doapache-pre-start'],
  }

  # setup hostname in conf.d
  file { 'doapache-conf-hostname' :
    name => "/etc/${apache::params::apache_name}/conf.d/hostname.conf",
    content => "ServerName ${fqdn}\nNameVirtualHost *:${port}\n",
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

  # setup php command line (symlink to php in zend server)
  file { 'php-command-line':
    name => '/usr/bin/php',
    ensure => 'link',
    target => '/usr/local/zend/bin/php',
    require => Anchor['doapache-package'],
  }

  # install PEAR to 1.9.2+ so it can use pear.drush.org without complaint
  class { 'pear':
    require => Anchor['doapache-package'],
  }

  # fix permissions on the /var/www/html directory (forced to root:root by apache install)
  # but only after we've created the web group ($group_name)
  $webfile = {
    '/var/www/html' => {
    },
  }
  $webfile_default = {
    user => $user,
    group => $group_name,
    require => [Exec['doapache-user-group-add'], File['common-webroot']],
  }
  create_resources(docommon::stickydir, $webfile, $webfile_default)

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
