# @summary
#   "Provider" for mysqldump
# @api private
#
class mysql::backup::mysqldump (
  $backupuser         = '',
  $backuppassword     = '',
  $backupdir          = '',
  $maxallowedpacket   = '1M',
  $backupdirmode      = '0700',
  $backupdirowner     = 'root',
  $backupdirgroup     = $mysql::params::root_group,
  $backupcompress     = true,
  $backuprotate       = 30,
  $backupmethod       = 'mysqldump',
  $ignore_events      = true,
  $delete_before_dump = false,
  $backupdatabases    = [],
  $file_per_database  = false,
  $include_triggers   = false,
  $include_routines   = false,
  $ensure             = 'present',
  $time               = ['23', '5'],
  $prescript          = false,
  $postscript         = false,
  $execpath           = '/usr/bin:/usr/sbin:/bin:/sbin',
  $optional_args      = [],
  $mysqlbackupdir_ensure = 'directory',
  $mysqlbackupdir_target = undef,
) inherits mysql::params {

  if $backupcompress {
    ensure_packages(['bzip2'])
    Package['bzip2'] -> File['mysqlbackup.sh']
  }

  mysql_user { "${backupuser}@localhost":
    ensure        => $ensure,
    password_hash => mysql::password($backuppassword),
    require       => Class['mysql::server::root_password'],
  }

  if $include_triggers  {
    $privs = [ 'SELECT', 'RELOAD', 'LOCK TABLES', 'SHOW VIEW', 'PROCESS', 'TRIGGER' ]
  } else {
    $privs = [ 'SELECT', 'RELOAD', 'LOCK TABLES', 'SHOW VIEW', 'PROCESS' ]
  }

  mysql_grant { "${backupuser}@localhost/*.*":
    ensure     => $ensure,
    user       => "${backupuser}@localhost",
    table      => '*.*',
    privileges => $privs,
    require    => Mysql_user["${backupuser}@localhost"],
  }

  if $::osfamily == 'RedHat' and $::operatingsystemmajrelease == '5' {
    package {'crontabs':
      ensure => present,
    }
  } elsif $::osfamily == 'RedHat' {
    package {'cronie':
      ensure => present,
    }
  } elsif $::osfamily != 'FreeBSD' {
    package {'cron':
      ensure => present,
    }
  }

  cron { 'mysql-backup':
    ensure  => $ensure,
    command => '/usr/local/sbin/mysqlbackup.sh',
    user    => 'root',
    hour    => $time[0],
    minute  => $time[1],
    require => File['mysqlbackup.sh'],
  }

  file { 'mysqlbackup.sh':
    ensure  => $ensure,
    path    => '/usr/local/sbin/mysqlbackup.sh',
    mode    => '0700',
    owner   => 'root',
    group   => $mysql::params::root_group,
    content => template('mysql/mysqlbackup.sh.erb'),
  }

  if $mysqlbackupdir_target {
    file { $backupdir:
      ensure => $mysqlbackupdir_ensure,
      target => $mysqlbackupdir_target,
      mode   => $backupdirmode,
      owner  => $backupdirowner,
      group  => $backupdirgroup,
    }
  } else {
    file { $backupdir:
      ensure => $mysqlbackupdir_ensure,
      mode   => $backupdirmode,
      owner  => $backupdirowner,
      group  => $backupdirgroup,
    }
  }

}
