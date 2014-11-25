class doapache::zendserver (

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
  
  # notifier dir for avoid repeat-runs
  $notifier_dir = '/etc/puppet/tmp',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # always use apache module's params
  include apache::params

  # install zend server
  # note: title still used by resource collectors
  package { 'doapache-zend-web-pack':
    name => "zend-server-php-${php_version}",
    ensure => 'present',
    tag => ['doapache-zend-package'],
  }

  # create a common anchor for external packages
  anchor { 'doapache-package' :
    require => Package['doapache-zend-web-pack'],
  }

  anchor { 'doapache-pre-start' :
    before => Service['doapache-zend-server-startup'],
  }

  # start zend server on startup
  service { 'doapache-zend-server-startup' :
    name => 'zend-server',
    enable => true,
    ensure => running,
    require => Augeas['doapache-php-ini'],
  }

  # remove redundant php.ini (/etc/php.ini)
  file { '/etc/php.ini' :
    ensure => absent,
    require => Anchor['doapache-package'],
    before => Anchor['doapache-pre-start'],
  }
  
  # install zend-specific bits of memcache if set
  if ($with_memcache == true) {
    # note no d
    if ! defined(Package["php-${php_version}-memcache-zend-server"]) {
      package { "php-${php_version}-memcache-zend-server" :
        ensure => 'present',
        alias => 'doapache-zend-php-memcache',
        tag => ['doapache-zend-package'],
        before => Service['doapache-memcache-startup'],
      }
    }
    # note d
    if ! defined(Package["php-${php_version}-memcached-zend-server"]) {
      package { "php-${php_version}-memcached-zend-server" :
        ensure => 'present',
        alias => 'doapache-zend-php-memcached',
        tag => ['doapache-zend-package'],
        before => Service['doapache-memcache-startup'],
      }
    }
  }

  # setup paths for all users to zend libraries/executables
  file { 'zend-libpath-forall':
    name => '/etc/profile.d/zend.sh',
    source => 'puppet:///modules/doapache/zend.sh',
    owner => 'root',
    group => 'root',
    mode => 0644,
    require => [Anchor['doapache-package'],File['php-command-line']],
  }
  # make the Dynamic Linker Run Time Bindings reread /etc/ld.so.conf.d
  exec { 'zend-ldconfig':
    path => '/sbin:/usr/bin:/bin',
    command => "bash -c 'source /etc/profile.d/zend.sh && ldconfig'",
    require => File['zend-libpath-forall'],
  }

  #
  # OS-specific bits
  # 
  case $operatingsystem {
    centos, redhat, fedora: {
      # setup the zend repo file
      if ($server_version != undef) {
        $repo_version_insert = "${server_version}/"
      } else {
        $repo_version_insert = ''
      }
      file { 'doapache-zend-repo-file':
        name => '/etc/yum.repos.d/zend.repo',
        content => template('doapache/zend.rpm.repo.erb'),
      }
      # make the package install dependent upon the reflash
      Package <| tag == 'doapache-zend-package' |> {
        require => File['doapache-zend-repo-file'],
      }
      # install SSH2
      package { 'doapache-zend-install-ssh2-module':
        name => "php-${php_version}-ssh2-zend-server",
        ensure => 'present',
        require => Anchor['doapache-package'],
        before => Anchor['doapache-pre-start'],
        tag => ['doapache-zend-package'],
      }
      # install mod SSL
      package { 'apache-mod-ssl' :
        name => 'mod_ssl',
        ensure => 'present',
        require => Anchor['doapache-package'],
        before => Anchor['doapache-pre-start'],
      }

      #
      # SELinux section
      #
      if (str2bool($::selinux)) {
        docommon::seport { 'tcp-10083' :
          port => 10083,
          seltype => 'http_port_t',
        }

        # temporarily disable SELinux beforehand
        exec { 'pre-install-disable-selinux' :
          path => '/usr/bin:/bin:/usr/sbin',
          command => 'setenforce 0',
          tag => ['service-sensitive'],
          before => Anchor['doapache-package'],
        }

        # stop zendserver, fix then re-enable SELinux
        exec { 'zend-selinux-fix-stop-do-ports' :
          path => '/usr/bin:/bin:/usr/sbin',
          # command => '/usr/local/zend/bin/zendctl.sh stop && semanage port -d -p tcp 10083 && semanage port -a -t http_port_t -p tcp 10083 && semanage port -m -t http_port_t -p tcp 10083 && setsebool -P httpd_can_network_connect 1',
          command => '/usr/local/zend/bin/zendctl.sh stop && setsebool -P httpd_can_network_connect 1',
          creates => "${notifier_dir}/puppet-doapache-selinux-fix",
          timeout => 600,
          tag => ['service-sensitive'],
          require => Anchor['doapache-package'],
        }

        # restart selinux if it was running when we started
        if (str2bool($::selinux_enforced)) {
          exec { 'zend-selinux-fix-start' :
            path => '/usr/bin:/bin:/usr/sbin',
            command => "setenforce 1",
            tag => ['service-sensitive'],
            require => [Exec['pre-install-disable-selinux'], Exec['zend-selinux-fix-stop-do-ports']],
            before => [Exec['zend-selinux-log-permfix']],
          }
          # these two fixes may not exist but, if they do, apply them before starting again
          Exec <| title == 'zend-selinux-fix-libs' |> {
            before => [Exec['zend-selinux-fix-start']],
          }
          Exec <| title == 'zend-selinux-fix-dirs' |> {
            before => [Exec['zend-selinux-fix-start']],
          }
        }

        # make log dir fix permanent to withstand a relabelling
        exec { 'zend-selinux-log-permfix' :
          path => '/usr/bin:/bin:/usr/sbin',
          command => "semanage fcontext -a -t httpd_log_t '/usr/local/zend/var/log(/.*)?' && touch ${notifier_dir}/puppet-doapache-selinux-fix",
          creates => "${notifier_dir}/puppet-doapache-selinux-fix",
          before => Anchor['doapache-pre-start'],
        }

        # 
        # DUPLICATE section
        # this section is duplicated in zendserver/override because it's version-specific
        # 
        case $server_version {
          5.6, undef: {
            # only clean up files for Zend Server 5.x
            exec { 'zend-selinux-fix-libs' :
              path => '/bin:/usr/bin:/sbin:/usr/sbin',
              # clear execstack bit every time, in case of upgrade (so no 'creates')
              command => 'execstack -c /usr/local/zend/lib/apache2/libphp5.so /usr/local/zend/lib/libssl.so.0.9.8 /usr/lib64/libclntsh.so.11.1 /usr/lib64/libnnz11.so /usr/local/zend/lib/libcrypto.so.0.9.8 /usr/local/zend/lib/debugger/php-5.*.x/ZendDebugger.so /usr/local/zend/lib/php_extensions/curl.so',
              tag => ['service-sensitive'],
              require => Exec['zend-selinux-fix-stop-do-ports'],
              before => [Anchor['doapache-pre-start']],
            }
            exec { 'zend-selinux-fix-dirs' :
              path => '/bin:/usr/bin:/sbin:/usr/sbin',
              # chcon is wiped by a relabelling, so use semanage && restorecon -R
              # command => 'chcon -R -t httpd_log_t /usr/local/zend/var/log && chcon -R -t httpd_tmp_t /usr/local/zend/tmp && chcon -R -t tmp_t /usr/local/zend/tmp/pagecache /usr/local/zend/tmp/datacache && chcon -t textrel_shlib_t /usr/local/zend/lib/apache2/libphp5.so /usr/lib*/libclntsh.so.11.1 /usr/lib*/libociicus.so /usr/lib*/libnnz11.so',
              command => 'semanage fcontext -a -t httpd_log_t "/usr/local/zend/var/log(/.*)?" && restorecon -R /usr/local/zend/var/log && semanage fcontext -a -t httpd_tmp_t "/usr/local/zend/tmp(/.*)?" && semanage fcontext -a -t tmp_t "/usr/local/zend/tmp/(pagecache|datacache)" && restorecon -R /usr/local/zend/tmp &&  semanage fcontext -a -t textrel_shlib_t "/usr/local/zend/lib/apache2/libphp5.so" && semanage fcontext -a -t textrel_shlib_t "/usr/lib*/libclntsh.so.11.1" && semanage fcontext -a -t textrel_shlib_t "/usr/lib*/libociicus.so" && semanage fcontext -a -t textrel_shlib_t "/usr/lib*/libnnz11.so"',
              creates => "${notifier_dir}/puppet-doapache-selinux-fix",
              timeout => 600,
              tag => ['service-sensitive'],
              require => Exec['zend-selinux-fix-stop-do-ports'],
              before => [Anchor['doapache-pre-start']],
            }
          }
          6.0, 6.1, 6.2, 6.3, default: {
            # no selinux cleanup specific to this version
            Exec <| title == 'zend-selinux-fix-libs' |> {
              noop => true,
            }
            Exec <| title == 'zend-selinux-fix-dirs' |> {
              noop => true,
            }
          }
        }
        #
        # End of duplicate section
        #
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
      file { 'doapache-zend-repo-file':
        name => '/etc/apt/sources.list.d/zend.list',
        # using special ubuntu.repo file, but eventually default back to deb.repo
        source => 'puppet:///modules/doapache/zend.ubuntu.repo',
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
      # @todo find pecl-ssh2 package for ubuntu
      # @todo find mod_ssl package for ubuntu
    }
  }
}
