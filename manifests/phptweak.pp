class doapache::phptweak (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',

  # by default work off the Zend Server (default) repo, options '6.0, 6.1, 6.2, 6.3'
  $server_provider = $doapache::params::server_provider,
  $server_version = $doapache::params::server_version,
  $php_version = $doapache::params::php_version,
  
  # php.ini setting defaults
  $php_path = $doapache::params::php_path,
  $php_timezone = $doapache::params::timezone,
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

  # tweak settings in php.ini [Main section]
  augeas { 'doapache-php-ini-tweak' :
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

}
