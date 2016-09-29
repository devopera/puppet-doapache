class doapache::params {

  case $operatingsystem {
    centos, redhat, fedora: {
      $confd_name = 'conf.d'
    }
    ubuntu, debian: {
      case $::operatingsystemmajrelease {
        '13.04', '14.04': {
          $confd_name = 'conf-enabled'
        }
        '12.04', default: {
          $confd_name = 'conf.d'
        }
      }
    }
  }


  # setup php and zendserver versions
  $server_provider = 'zend'
  case $::operatingsystem {
    centos, redhat: {
      case $::operatingsystemmajrelease {
        '7': {
          $server_version = '8.5.4'
          $php_version = '5.6'
        }
        '6', default: {
          $server_version = '6.3'
          $php_version = '5.3'
        }
      }
    }
    ubuntu, debian: {
      case $::operatingsystemmajrelease {
        '13.04', '14.04': {
          $server_version = '8.5.4'
          $php_version = '5.6'
        }
        '12.04', default: {
          $server_version = '6.3'
          $php_version = '5.3'
        }
      }
    }
  }

  case $server_provider {
    'zend', default: {
      $php_path = '/usr/local/zend/etc/php.ini'
    }
    'apache': {
      $php_path = '/etc/php.ini'
    }
  }

}

