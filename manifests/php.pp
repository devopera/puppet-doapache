class doapache::php (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',

  # by default work off the Zend Server (default) repo, options '6.0, 6.1, 6.2, 6.3'
  $server_provider = 'zend',
  $server_version = undef,
  # by default, install php 5.3, option '5.4, 5.5'
  $php_version = '5.3',
  
  # php.ini setting defaults
  $php_path = $doapache::params::php_path,
  $php_timezone = 'Europe/London',
  $php_memory_limit = '128M',
  $php_post_max_size = '10M',
  $php_upload_max_filesize = '10M',
  $php_internal_encoding = 'UTF-8',
  $php_session_gc_maxlifetime = '1440',
  $php_max_input_vars = '1000',

  # notifier dir for avoid repeat-runs
  $notifier_dir = '/etc/puppet/tmp',

  # end of class arguments
  # ----------------------
  # begin class

) inherits doapache::params {

  case $server_provider {
    'zend': {
      # zendserver comes bundled with php

      # setup php command line (symlink to php in zend server)
      file { 'php-command-line':
        name => '/usr/bin/php',
        ensure => 'link',
        target => '/usr/local/zend/bin/php',
        require => Anchor['doapache-package'],
      }

    }
    'apache': {
      # strip period from php version to get lib name
      $php_version_safe = regsubst($php_version, '\.', '')

      package { 'php' : }
      package { 'php-mysql' : }
      package { 'php-cli' : }
      package { 'php-common' : }

      # non-zend PHP isn't really supported yet
      #
      #class { 'apache::mod::php':
      #  package_name => "php${php_version_safe}-php",
      #  path         => "${::apache::params::lib_path}/libphp${php_version_safe}-php5.so",
      #}
    }
  }

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

  # install PEAR to 1.9.2+ so it can use pear.drush.org without complaint
  class { 'pear':
    require => Anchor['doapache-package'],
  }

}
