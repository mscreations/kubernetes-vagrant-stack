# -*- mode: ruby -*-
# vi: set ft=ruby :

NETWORK_PREFIX      = ENV['NETWORK_PREFIX']
POD_NETWORK         = ENV['POD_NETWORK']
VAGRANT_BOX         = ENV['VAGRANT_BOX']

MASTER_NODES_COUNT  = ENV['MASTER_NODES_COUNT'].to_i
MASTER_MAX_CPUS     = ENV['MASTER_MAX_CPUS'].to_i
MASTER_MAX_MEMORY   = ENV['MASTER_MAX_MEMORY'].to_i

WORKER_NODES_COUNT  = ENV['WORKER_NODES_COUNT'].to_i
WORKER_MAX_CPUS     = ENV['WORKER_MAX_CPUS'].to_i
WORKER_MAX_MEMORY   = ENV['WORKER_MAX_MEMORY'].to_i

# Field names for servers array
NODE_NAME = 0
MAX_MEMORY = 1
MAX_CPUS = 2
MAC_ADDRESS = 3
IP_ADDRESS = 4
MODE = 5

j = 0
servers = Array.new
(0..(MASTER_NODES_COUNT - 1)).each do |i|
  if i == 0
    mode = "init"
  else
    mode = "master"
  end
  servers.push(["kmaster#{i+1}", MASTER_MAX_MEMORY, MASTER_MAX_CPUS, "00155d01020#{j}", "#{NETWORK_PREFIX}.20#{j + 1}", mode])
  j += 1
end
(0..(WORKER_NODES_COUNT - 1)).each do |i|
    servers.push(["kworker#{i+1}", WORKER_MAX_MEMORY, WORKER_MAX_CPUS, "00155d01020#{j}", "#{NETWORK_PREFIX}.20#{j + 1}", "worker"])
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

Vagrant.configure("2") do |config|
  config.vagrant.plugins = ['vagrant-reload']
  config.vm.box = VAGRANT_BOX
  config.vm.synced_folder ".", "/vagrant", mount_options: ["uid=1000", "gid=1000"], smb_username: ENV['DOMAIN_USER'], smb_password: ENV['DOMAIN_PASSWORD']
  config.vm.allow_fstab_modification = true
  
  # Run customization ansible scripts for all hosts (scripts not in git)
  # These scripts setup the customized shell that has my specific preferences
  # Needs to be completed prior to stage 1 as it will patch the profile there.
  Dir.glob("customize/*.y{a,}ml").each do |playbook|
    config.vm.provision "ansible_local" do |ansible|
      ansible.playbook = playbook
    end
  end

  # Run customization ansible scripts for all hosts that are stored in git
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook          = "ansible/stage1.yml"
    ansible.galaxy_role_file  = "ansible/requirements.yml"
    ansible.extra_vars = {
      new_ssh_password: ENV['NEW_SSH_PASSWORD'],
      domain_password: ENV['DOMAIN_PASSWORD'],
      domain: ENV["DOMAIN"],
      k8s_version: ENV["K8S_VERSION"]
    }
  end
  
  p "Status #{created}"
  config.vm.provision :reload

  servers.each do |server|
    config.vm.define server[NODE_NAME] do |node|
      node.vm.network "public_network", bridge: "LAN"
      node.vm.hostname = "#{server[NODE_NAME]}.#{ENV['DOMAIN']}"

      if server[MODE] == "worker"
        node.vm.disk :disk, size: "100GB", name: "#{server[NODE_NAME]}-disk-1"
        node.vm.disk :disk, size: "100GB", name: "#{server[NODE_NAME]}-disk-2"
      end

      node.vm.provider :hyperv do |h, override|
        
        created = `powershell -ExecutionPolicy Bypass -File "./powershell/check_status.ps1" -VMName "k8s (#{server[NODE_NAME]})"`
        p "Check status of k8s (#{server[NODE_NAME]})"
        p "Status #{created}"

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
          trigger.run = {inline: "./powershell/dhcp.ps1 -Hostname #{server[NODE_NAME]}.#{ENV['DOMAIN']} -ScopeId #{NETWORK_PREFIX}.0 -MACAddress #{server[MAC_ADDRESS]} -IPAddress #{server[IP_ADDRESS]} -DHCPServer #{ENV['DHCP_SERVER']} -Username #{ENV['DOMAIN_USER']} -Password #{ENV['DOMAIN_PASSWORD']}"}
        end
        override.trigger.after :'VagrantPlugins::HyperV::Action::Import', type: :action do |trigger|
          trigger.run = {inline: "./powershell/reset_uuid.ps1 -VMName \"k8s (#{server[NODE_NAME]})\""}
        end
        override.trigger.before :'VagrantPlugins::HyperV::Action::DeleteVM', type: :action do |trigger|
          trigger.run = {inline: "./powershell/dhcp.ps1 -Hostname #{server[NODE_NAME]}.#{ENV['DOMAIN']} -ScopeId #{NETWORK_PREFIX}.0 -MACAddress #{server[MAC_ADDRESS]} -IPAddress #{server[IP_ADDRESS]} -DHCPServer #{ENV['DHCP_SERVER']} -Username #{ENV['DOMAIN_USER']} -Password #{ENV['DOMAIN_PASSWORD']} -RemoveReservation"}
        end
      end
    end
  end

  config.trigger.before :destroy do |trigger|
    trigger.info = "Disconnecting from the domain"
    trigger.on_error = :continue
    trigger.run_remote = {
      path: "/vagrant/unjoin_domain.sh", 
      env: { 
        "DOMAIN_PASS" => ENV['DOMAIN_PASSWORD']
      }
    }
  end
end
