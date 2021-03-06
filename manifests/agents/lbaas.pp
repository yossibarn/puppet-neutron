# == Class: neutron::agents:lbaas:
#
# Setups Neutron Load Balancing agent.
#
# === Parameters
#
# [*package_ensure*]
#   (optional) Ensure state for package. Defaults to 'present'.
#
# [*enabled*]
#   (optional) Enable state for service. Defaults to 'true'.
#
# [*manage_service*]
#   (optional) Whether to start/stop the service
#   Defaults to true
#
# [*debug*]
#   (optional) Show debugging output in log. Defaults to false.
#
# [*interface_driver*]
#   (optional) Defaults to 'neutron.agent.linux.interface.OVSInterfaceDriver'.
#
# [*device_driver*]
#   (optional) Defaults to 'neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver'.
#
# [*user_group*]
#   (optional) The user group.
#   Defaults to $::neutron::params::nobody_user_group
#
# [*manage_haproxy_package*]
#   (optional) Whether to manage the haproxy package.
#   Disable this if you are using the puppetlabs-haproxy module
#   Defaults to true
#
# === Deprecated Parameters
#
# [*use_namespaces*]
#   (optional) Deprecated. 'True' value will be enforced in future releases.
#   Allow overlapping IP (Must have kernel build with
#   CONFIG_NET_NS=y and iproute2 package that supports namespaces).
#   Defaults to $::os_service_default.
#
class neutron::agents::lbaas (
  $package_ensure         = present,
  $enabled                = true,
  $manage_service         = true,
  $debug                  = false,
  $interface_driver       = 'neutron.agent.linux.interface.OVSInterfaceDriver',
  $device_driver          = 'neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver',
  $user_group             = $::neutron::params::nobody_user_group,
  $manage_haproxy_package = true,
  # DEPRECATED PARAMETERS
  $use_namespaces         = $::os_service_default,
) {

  include ::neutron::params

  Neutron_config<||>             ~> Service['neutron-lbaas-service']
  Neutron_lbaas_agent_config<||> ~> Service['neutron-lbaas-service']

  case $device_driver {
    /\.haproxy/: {
      Package <| title == $::neutron::params::haproxy_package |> -> Package <| title == 'neutron-lbaas-agent' |>
      if $manage_haproxy_package {
        ensure_packages([$::neutron::params::haproxy_package])
      }
    }
    default: {
      fail("Unsupported device_driver ${device_driver}")
    }
  }

  # The LBaaS agent loads both neutron.ini and its own file.
  # This only lists config specific to the agent.  neutron.ini supplies
  # the rest.
  neutron_lbaas_agent_config {
    'DEFAULT/debug':              value => $debug;
    'DEFAULT/interface_driver':   value => $interface_driver;
    'DEFAULT/device_driver':      value => $device_driver;
    'haproxy/user_group':         value => $user_group;
  }

  if ! is_service_default ($use_namespaces) {
    warning('The use_namespaces parameter is deprecated and will be removed in future releases')
    neutron_lbaas_agent_config {
      'DEFAULT/use_namespaces':   value => $use_namespaces;
    }
  }

  Package['neutron']            -> Package['neutron-lbaas-agent']
  package { 'neutron-lbaas-agent':
    ensure => $package_ensure,
    name   => $::neutron::params::lbaas_agent_package,
    tag    => ['openstack', 'neutron-package'],
  }
  if $manage_service {
    if $enabled {
      $service_ensure = 'running'
    } else {
      $service_ensure = 'stopped'
    }
    Package['neutron'] ~> Service['neutron-lbaas-service']
    Package['neutron-lbaas-agent'] ~> Service['neutron-lbaas-service']
  }

  service { 'neutron-lbaas-service':
    ensure  => $service_ensure,
    name    => $::neutron::params::lbaas_agent_service,
    enable  => $enabled,
    require => Class['neutron'],
    tag     => 'neutron-service',
  }
}
