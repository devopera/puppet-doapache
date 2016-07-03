class doapache::zendserver::repo (

  # class arguments
  # ---------------
  # setup defaults

  $server_version = undef,

  # end of class arguments
  # ----------------------
  # begin class

) {
  if ($server_version != undef) {
    $repo_version_insert = "${server_version}/"
  } else {
    $repo_version_insert = ''
  }

  case $::operatingsystem {
    centos, redhat: {
      case $::operatingsystemmajrelease {
        '7', default: {
          # Apache 2.4
          file { 'doapache-zend-repo-file':
            name => '/etc/yum.repos.d/zend.repo',
            content => template('doapache/zend.rpm_apache2.4.repo.erb'),
          }
        }
        '6': {
          # Apache 2.2
          file { 'doapache-zend-repo-file':
            name => '/etc/yum.repos.d/zend.repo',
            content => template('doapache/zend.rpm.repo.erb'),
          }
        }
      }
    }
    ubuntu, debian: {
      # install key
      exec { 'zend-repo-key' :
        path => '/usr/bin:/bin',
        command => 'wget http://repos.zend.com/zend.key -O- | sudo apt-key add -',
        cwd => '/tmp/',
      }
      # setup repo
      case $::operatingsystemmajrelease {
        '13.04', '14.04', default: {
          # Apache 2.4
          file { 'doapache-zend-repo-file':
            name => '/etc/apt/sources.list.d/zend.list',
            content => template('doapache/zend.deb_apache2.4.repo.erb'),
          }
        }
        '12.04': {
          # Apache 2.2
          file { 'doapache-zend-repo-file':
            name => '/etc/apt/sources.list.d/zend.list',
            content => template('doapache/zend.deb.repo.erb'),
          }
        }
      }
      # re-flash the repos
      exec { 'zend-repo-reflash':
        path => '/usr/bin:/bin',
        command => 'sudo apt-get update',
        require => [Exec['zend-repo-key'], File['doapache-zend-repo-file']],
      }
      # make the package install dependent upon the reflash
      Package <| tag == 'doapache-zend-package' |> {
        require => Exec['zend-repo-reflash'],
      }

    }
  }

  # make the package install dependent upon the reflash
  Package <| tag == 'doapache-zend-package' |> {
    require => File['doapache-zend-repo-file'],
  }
}
