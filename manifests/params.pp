class doapache::params {

  case $operatingsystem {
    centos, redhat, fedora: {
      $confd_name = 'conf.d'
    }
    ubuntu, debian: {
      case $operatingsystemmajrelease {
        '13.04', '14.04': {
          $confd_name = 'conf-enabled'
        }
        '12.04', default: {
          $confd_name = 'conf.d'
        }
      }
    }
  }

  case $server_provider {
    'zend': {
      $php_path = '/usr/local/zend/etc/php.ini'
    }
    'apache': {
      $php_path = '/etc/php.ini'
    }
  }

}

