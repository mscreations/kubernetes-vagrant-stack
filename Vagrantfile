# -*- mode: ruby -*-
# vi: set ft=ruby :

require_relative 'secrets.rb'
include Secrets
include Constants

ENV['VAGRANT_FORCE_COLOR'] = 'yes'
ENV['VAGRANT_INSTALL_LOCAL_PLUGINS'] = 'yes'

# Field names for servers array
NODE_NAME = 0
MAX_MEMORY = 1
MAX_CPUS = 2
MAC_ADDRESS = 3
IP_ADDRESS = 4
MODE = 5

j = 0
servers = Array.new
(0..(Constants::MASTER_NODES_COUNT - 1)).each do |i|
  if i == 0
    mode = "init"
  else
    mode = "master"
  end
  servers.push(["kmaster#{i+1}", Constants::MASTER_MAX_MEMORY, Constants::MASTER_MAX_CPUS, "00155d01020#{j}", "#{Constants::NETWORK_PREFIX}.20#{j + 1}", mode])
  j += 1
end
(0..(Constants::WORKER_NODES_COUNT - 1)).each do |i|
    servers.push(["kworker#{i+1}", Constants::WORKER_MAX_MEMORY, Constants::WORKER_MAX_CPUS, "00155d01020#{j}", "#{Constants::NETWORK_PREFIX}.20#{j + 1}", "worker"])
    j += 1
end

# Print servers array as grid
headers = ["NODE_NAME", "MAX_MEMORY", "MAX_CPUS", "MAC_ADDRESS", "IP_ADDRESS", "MODE"]
puts "Servers to be created:"
puts headers.map { |h| h.ljust(16) }.join("| ")
puts "-" * ((headers.size * 16) + 10)
servers.each do |server|
  puts server.map { |v| v.to_s.ljust(16) }.join("| ")
end

# Ensure secrets are listed as sensitive in logs
sensitive_values = Secrets.constants.map { |const| Secrets.const_get(const) }

Vagrant.configure("2") do |config|
  config.vagrant.sensitive = sensitive_values

  config.vm.box = Constants::VAGRANT_BOX
  config.vm.synced_folder ".", "/vagrant", mount_options: ["uid=1000", "gid=1000"], smb_username: Secrets::DOMAIN_USER, smb_password: Secrets::DOMAIN_PASSWORD

  servers.each do |server|
    config.vm.define server[NODE_NAME] do |node|
      node.vm.network "public_network", bridge: "LAN"
      node.vm.hostname = "#{server[NODE_NAME]}.#{Secrets::DOMAIN}"

      if server[MODE] == "worker"
        node.vm.disk :disk, size: "100GB", name: "#{server[NODE_NAME]}-disk-1"
        node.vm.disk :disk, size: "100GB", name: "#{server[NODE_NAME]}-disk-2"
      end

      node.vm.provider :hyperv do |h, override|
        h.memory      = server[MAX_MEMORY]
        h.cpus        = server[MAX_CPUS]
        h.vmname      = "k8s (#{server[NODE_NAME]})"
        h.mac         = server[MAC_ADDRESS]
        h.vm_integration_services = {
          guest_service_interface: true,
          heartbeat: true,
          key_value_pair_exchange: true,
          shutdown: true,
          time_synchronization: true,
          vss: true
        }
        h.auto_start_action = "Start"
        h.auto_stop_action = "ShutDown"

        # Manually add in DHCP reservation for VM
        override.trigger.after :'VagrantPlugins::HyperV::Action::Import', type: :action do |trigger|
          trigger.run = {inline: "./dhcp.ps1 -Hostname #{server[NODE_NAME]}.#{Secrets::DOMAIN} -ScopeId #{Constants::NETWORK_PREFIX}.0 -MACAddress #{server[MAC_ADDRESS]} -IPAddress #{server[IP_ADDRESS]} -DHCPServer #{Secrets::DHCP_SERVER} -Username #{Secrets::DOMAIN_USER} -Password #{Secrets::DOMAIN_PASSWORD}"}
        end
        override.trigger.before :'VagrantPlugins::HyperV::Action::DeleteVM', type: :action do |trigger|
          trigger.run = {inline: "./dhcp.ps1 -Hostname #{server[NODE_NAME]}.#{Secrets::DOMAIN} -ScopeId #{Constants::NETWORK_PREFIX}.0 -MACAddress #{server[MAC_ADDRESS]} -IPAddress #{server[IP_ADDRESS]} -DHCPServer #{Secrets::DHCP_SERVER} -Username #{Secrets::DOMAIN_USER} -Password #{Secrets::DOMAIN_PASSWORD} -RemoveReservation"}
        end
      end
    end
  end

end
