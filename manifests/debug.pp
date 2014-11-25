class doapache::debug (

  # class arguments
  # ---------------
  # setup defaults

  $server_provider = 'zend',
  $admin_port = 10081,
  $php_path = '/usr/local/zend/etc/php.ini',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # set apache/PHP to show errors
  augeas { 'doapache-php-ini-display-errors' :
    context => "/files${php_path}/PHP",
    changes => [
     'set display_errors On',
    ],
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }

  if ($server_provider == 'zend') {
    # open up Zend Server admin port
    @docommon::fireport { "${admin_port} Zend Server debugging port":
      protocol => 'tcp',
      port => $admin_port,
    }
    # if we've got a message of the day, include Zend
    @domotd::register { "Zend(${admin_port})" : }
  }
}
