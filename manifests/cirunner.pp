# @summary This module installs and configures Gitlab CI Runners.
# @param conf_file path to the config file
# @param url the url to the gitlab server
# @param concurrent override the default number of concurrent job
# @param runners the hash of runners
#
class gitlab::cirunner (
  String               $conf_file  = '/etc/gitlab-runner/config.toml',
  String               $url        = 'https://gitlab.com',
  Optional[Integer[1]] $concurrent = undef,
  Hash                 $runners    = {},
) {
  $_concurrent = pick($concurrent, $runners.size)
  $package_name = 'gitlab-runner'
  ensure_packages([$package_name])

  exec { 'gitlab-runner-restart':
    command     => "/usr/bin/${package_name} restart",
    refreshonly => true,
    require     => Package[$package_name],
  }
  $runners.each |$name, $config| {
    $command = "/usr/bin/gitlab-ci-multi-runner register -n --executor shell --token ${config['token']} --url ${url}"
    exec { "Register_runner ${name}":
      command => $command,
      unless  => "/bin/grep ${config['token']} ${conf_file}",
      require => Package[$package_name],
    }
    if 'limit' in $config {
      file_line { "gitlab-runner-limit-${name}":
        path    => $conf_file,
        line    => "  limit = ${config['limit']}",
        after   => "^.+${config['token']}",
        require => Exec["Register_runner ${name}"],
        notify  => Exec['gitlab-runner-restart'],
      }
    }
  }
  file_line { 'gitlab-runner-concurrent':
    path   => $conf_file,
    line   => "concurrent = ${_concurrent}",
    match  => '^concurrent = \d+',
    notify => Exec['gitlab-runner-restart'],
  }
}
