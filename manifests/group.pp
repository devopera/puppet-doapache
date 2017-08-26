class doapache::group (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  $group_name = 'www-data',

  # notifier dir for avoid repeat-runs
  $notifier_dir = '/etc/puppet/tmp',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # modify apache conf file (after apache module) to use our web $group_name and turn off ServerSignature
  $signatureSed = "-e 's/ServerSignature On/ServerSignature Off/'"
  case $operatingsystem {
    centos, redhat, fedora: {
      $apache_conf_command = "sed -i -e 's/Group apache/Group ${group_name}/' ${signatureSed} ${apache::params::conf_dir}/${apache::params::conf_file}"
      $apache_conf_if = "grep -c 'Group apache' ${apache::params::conf_dir}/${apache::params::conf_file}"
      $apache_member_list = "${user},apache${webserver_user_group_append}"
    }
    ubuntu, debian: {
      # the www-data string is used here because we're substituting what ubuntu inserts with our var $group_name
      $apache_conf_command = "sed -i -e 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=${group_name}/' ${signatureSed} /etc/${apache::params::apache_name}/envvars"
      $apache_conf_if = "grep -c 'APACHE_RUN_GROUP=www-data' /etc/${apache::params::apache_name}/envvars"
      # ubuntu doesn't have an apache user, only www-data
      $apache_member_list = "${user}${webserver_user_group_append}"
    }
  }
  exec { 'doapache-web-group-hack' :
    path => '/usr/bin:/bin:/sbin',
    command => "$apache_conf_command",
    require => Anchor['doapache-package'],
  }->
  # create www-data group and give web/webserver-user access to it
  exec { 'doapache-user-group-add' :
    path => '/usr/bin:/usr/sbin',
    command => "groupadd -f ${group_name} -g 5000 && gpasswd -M ${apache_member_list} ${group_name}",
    before => Anchor['doapache-pre-start'],
  }->
  # apply www-data group to web root folder (less crucial now)
  exec { 'doapache-group-apply-to-web' :
    path => '/bin:/sbin:/usr/bin:/usr/sbin',
    command => "chgrp ${group_name} -R /var/www",
    before => Anchor['doapache-pre-start'],
  }

  # fix permissions on the /var/www/html directory (forced to root:root by apache install)
  # but only after we've created the web group ($group_name)
  $webfile = {
    '/var/www/html' => {
    },
  }
  $webfile_default = {
    user => $user,
    group => $group_name,
    require => [Exec['doapache-user-group-add']],
  }
  create_resources(docommon::stickydir, $webfile, $webfile_default)

}
