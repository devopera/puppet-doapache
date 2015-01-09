class doapache::firewall (

  # class arguments
  # ---------------
  # setup defaults

  $port = undef,
  $port_https = undef,

  # end of class arguments
  # ----------------------
  # begin class

) {

  if ($port != undef) {
    @docommon::fireport { "000${port} HTTP web service":
      protocol => 'tcp',
      port     => $port,
    }
  }
  
  if ($port_https != undef) {
    @docommon::fireport { "00${port_https} HTTPS web service":
      protocol => 'tcp',
      port     => $port_https,
    }
  }
  
}
