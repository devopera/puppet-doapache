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
  file { 'doapache-zend-repo-file':
    name => '/etc/yum.repos.d/zend.repo',
    content => template('doapache/zend.rpm.repo.erb'),
  }
  # make the package install dependent upon the reflash
  Package <| tag == 'doapache-zend-package' |> {
    require => File['doapache-zend-repo-file'],
  }
}
