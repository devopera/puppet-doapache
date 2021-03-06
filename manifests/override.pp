class doapache::override (

  # allow profiles to effectively override class resource attributes
  $server_provider = 'zend',
  $server_version,
  $php_version,

) inherits doapache {

  # override all resources that use the override variables above
  # whether used or not

  if ($server_provider == 'zend') {
    # setup the zend repo file
    if ($server_version != undef) {
      $repo_version_insert = "${server_version}/"
    } else {
      $repo_version_insert = ''
    }
    File <| title == 'doapache-zend-repo-file' |> {
      content => template('doapache/zend.rpm.repo.erb'),
    }

    # deploy resource collectors for overrides
    Package <| title == 'doapache-zend-web-pack' |> {
      name => "zend-server-php-${php_version}",
    }

    Package <| title == 'doapache-zend-install-ssh2-module' |> {
      name => "php-${php_version}-ssh2-zend-server",
    }

    Package <| alias == 'doapache-zend-php-memcache' |> {
      name => "php-${php_version}-memcache-zend-server",
    }

    Package <| alias == 'doapache-zend-php-memcached' |> {
      name => "php-${php_version}-memcached-zend-server",
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

