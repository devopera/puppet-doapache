class doapache::params {

  $timezone = 'Etc/UTC'

  case $operatingsystem {
    centos, redhat, fedora: {
      $confd_name = 'conf.d'
    }
    ubuntu, debian: {
      case $::operatingsystemmajrelease {
        '13.04', '14.04', default: {
          $confd_name = 'conf-enabled'
        }
        '12.04': {
          $confd_name = 'conf.d'
        }
      }
    }
  }

  $apache_server_version = 'present'

  # setup php and zendserver versions
  $server_provider = 'zend'
  case $::operatingsystem {
    centos, redhat: {
      case $::operatingsystemmajrelease {
        '7', default: {
          $zend_server_version = '8.5'
          $php_version = '5.6'
        }
        '6': {
          $zend_server_version = '6.3'
          $php_version = '5.3'
        }
      }
    }
    ubuntu, debian: {
      case $::operatingsystemmajrelease {
        '13.04', '14.04', default: {
          $zend_server_version = '8.5'
          $php_version = '5.6'
        }
        '12.04': {
          $zend_server_version = '6.3'
          $php_version = '5.3'
        }
      }
    }
  }

  $zend_php_path = '/usr/local/zend/etc/php.ini'
  $apache_php_path = '/etc/php.ini'

}

