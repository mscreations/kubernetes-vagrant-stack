pipeline {
  agent { label 'hyperv' }
  options {
    ansiColor('xterm')
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '30', numToKeepStr: '15'))
  }
  environment {
    VAGRANT_DOTFILE_PATH='D:\\Jenkins\\.vagrant'
    VAGRANT_FORCE_COLOR=1
    VAGRANT_INSTALL_LOCAL_PLUGINS=1
    ANSIBLE_FORCE_COLOR = 1
  }
  triggers {
    pollSCM('*/2 * * * *')
  }
  parameters {
    string(defaultValue: '1.34', name: 'K8S_VERSION', trim: true)
    booleanParam(name: 'TEARDOWN')
    string(name: 'VAGRANT_EXTRA_ARGS', trim: true)
    booleanParam(name: 'UPDATE_BOX')
    string(defaultValue: '172.29.125', name: 'NETWORK_PREFIX', trim: true)
    string(defaultValue: 'mscreations/ubuntu2404', name: 'VAGRANT_BOX', trim: true)
    string(defaultValue: '3', name: 'CONTROLPLANE_NODES_COUNT', trim: true)
    string(defaultValue: '4', name: 'CONTROLPLANE_MAX_CPUS', trim: true)
    string(defaultValue: '4096', name: 'CONTROLPLANE_MAX_MEMORY', trim: true)
    string(defaultValue: '3', name: 'WORKER_NODES_COUNT', trim: true)
    string(defaultValue: '16', name: 'WORKER_MAX_CPUS', trim: true)
    string(defaultValue: '32768', name: 'WORKER_MAX_MEMORY', trim: true)
  }
  stages {
    stage('Checkout') {
      agent { label 'hyperv' }
      steps {
        bat("git config --global core.autocrlf false")
        powershell("Remove-Item -Path 'customize\\' -Recurse -Force -ErrorAction SilentlyContinue")
        checkout([
          $class: 'GitSCM',
          branches: [[name: 'dev']],
          doGenerateSubmoduleConfigurations: false,
          extensions: [[$class: 'WipeWorkspace']],
          userRemoteConfigs: [[url: 'git@github.com:mscreations/kubernetes-vagrant-stack.git', credentialsId: 'Github']]
        ])

        powershell("""
          Copy-Item -Path '..\\..\\Kubernetes\\customize\\*' -Destination 'customize\\' -Recurse -Force
        """)

        stash(includes: '**', name: 'SourceFiles')
      }
    }
    stage('Generate Servers + Inventory') {
      agent { label 'linux' }
      steps {
        sh('rm -rf customize')
        unstash(name: 'SourceFiles')
        sh('chmod +x ./scripts/generate_servers.sh')
        script {
          def output = sh(script: './scripts/generate_servers.sh', returnStdout: true).trim()
          writeFile(file: 'servers.txt', text: output)
        }
        stash(includes: 'servers.txt,inventory.ini', name: 'configFiles')
      }
    }
    stage('Prepare Jenkins SSH Key') {
      agent { label 'linux' }
      when {
        expression { !params.TEARDOWN }
      }
      steps {
        script {
          env.JENKINS_HOME_DIR = sh(
            script: "getent passwd jenkins | cut -d: -f6",
            returnStdout: true
          ).trim()

          if (!env.JENKINS_HOME_DIR) {
            error "Cannot determine home directory for jenkins user."
          }

          def sshDir = "${env.JENKINS_HOME_DIR}/.ssh"
          def keyFile = "${sshDir}/id_ansible"

          sh("""
            mkdir -p "${sshDir}"
            chmod 700 "${sshDir}"

            if [ ! -f "${keyFile}" ]; then
              ssh-keygen -t rsa -b 4096 -f "${keyFile}" -N ""
            fi
          """)

          // Read public key into env variable
          env.SSH_KEY = sh(
            script: "cat ${keyFile}.pub",
            returnStdout: true
          ).trim()

          // Update SSH config for servers in servers.txt
          def servers = readFile('servers.txt').trim().split("\\r?\\n")
          def sshConfigFile = "${sshDir}/config"

          sh("""
            touch "${sshConfigFile}"
            chmod 600 "${sshConfigFile}"
          """)

          servers.each { line ->
            def field = line.split(',')
            def server = field[0]
            sh("""
              # Remove old entry for host to avoid duplicates
              sed -i '/Host ${server}/,+5d' "${sshConfigFile}"

              # Add new entry
              echo "Host ${server}" >> "${sshConfigFile}"
              echo "    HostName ${server}" >> "${sshConfigFile}"
              echo "    User vagrant" >> "${sshConfigFile}"
              echo "    IdentityFile ${keyFile}" >> "${sshConfigFile}"
              echo "    StrictHostKeyChecking no" >> "${sshConfigFile}"
              echo "    UserKnownHostsFile /dev/null" >> "${sshConfigFile}"
            """)
          }

          echo "SSH key ready at ${keyFile}, SSH config updated."
        }
      }
    }
    stage('Check VM Status') {
      agent { label 'hyperv' }
      when {
        expression { !params.TEARDOWN }
      }
      steps {
        unstash(name: 'configFiles')

        script {
          def servers = readFile('servers.txt').trim().split("\n")
          def allCreated = true
          def skipVagrant = false

          for (line in servers) {
            def parts = line.split(',')
            def name = parts[0]
            def status = bat(
              script: """
                @echo off
                powershell -NoProfile -ExecutionPolicy Bypass -File ./powershell/check_status.ps1 -VMName ${name}
              """,
              returnStdout: true
            ).trim()


            if (status != "Created") {
              allCreated = false
            }

            echo(message: "VM ${name} status: ${status}")
          }

          if (allCreated) {
            echo(message: "All VMs exist, skipping vagrant up")
            skipVagrant = true
          }
          env.SKIP_VAGRANT = skipVagrant.toString()
        }
      }
    }
    stage('Run Vagrant') {
      agent { label 'hyperv' }
      when {
        anyOf {
          expression { params.TEARDOWN }
          expression { env.SKIP_VAGRANT == 'false' }
        }
      }
      steps {
        withInfisical(
          configuration: [infisicalCredentialId: 'infisical',infisicalEnvironmentSlug: 'prod',infisicalProjectSlug: 'homelab-b-h-sw'],
          infisicalSecrets: [infisicalSecret(includeImports: true, path: '/', secretValues: [[infisicalKey: 'DOMAIN_USER'],[infisicalKey: 'DOMAIN_PASSWORD'],[infisicalKey: 'DOMAIN'],[infisicalKey: 'DHCP_SERVER']])]) {
          script {
            if (params.TEARDOWN) {
              echo(message: "Tearing down existing VMs")
              bat("vagrant destroy -f")
            }
            else if (params.UPDATE_BOX) {
              echo(message: "Updating Vagrant box and bringing up VMs")
              bat("vagrant box update --box $VAGRANT_BOX")
              bat("vagrant up $VAGRANT_EXTRA_ARGS")
            }
            else {
              echo(message: "Bringing up VMs with Vagrant")
              bat("vagrant up $VAGRANT_EXTRA_ARGS")
            }
          }
        }
      }
    }
    stage('Stage 1 Provision') {
      agent { label 'linux' }
      when {
        expression { !params.TEARDOWN }
      }
      steps {
        withInfisical(configuration: [infisicalCredentialId: 'infisical',infisicalEnvironmentSlug: 'prod',infisicalProjectSlug: 'homelab-b-h-sw',infisicalUrl: 'https://app.infisical.com'],
          infisicalSecrets: [infisicalSecret(includeImports: true, path: '/', secretValues: [[infisicalKey: 'DOMAIN_PASSWORD'],[infisicalKey: 'DOMAIN'],[infisicalKey: 'NEW_SSH_PASSWORD']])]) {
          script {
            sh('''
              chmod +x ./scripts/deploy_customizations.sh
              ./scripts/deploy_customizations.sh
              ansible-galaxy install -r ./ansible/requirements.yml -p /etc/ansible/roles --force

              ansible-playbook -i inventory.ini \
                ./ansible/stage1.yml\
                -e "new_ssh_password=${NEW_SSH_PASSWORD}" \
                -e "domain_password=${DOMAIN_PASSWORD}" \
                -e "domain=${DOMAIN}" \
                -e "k8s_version=${K8S_VERSION}"
            ''')
          }
        }
      }
    }
    stage('Init k8s Cluster') {
      agent { label 'linux' }
      when {
        expression { !params.TEARDOWN }
      }
      steps {
        withInfisical(configuration: [infisicalCredentialId: 'infisical',infisicalEnvironmentSlug: 'prod',infisicalProjectSlug: 'homelab-b-h-sw',infisicalUrl: 'https://app.infisical.com'],
          infisicalSecrets: [infisicalSecret(includeImports: true, path: '/', secretValues: [[infisicalKey: 'K8S_TOKEN'],[infisicalKey: 'K8S_CERTIFICATE_KEY'],[infisicalKey: 'K8S_ENCRYPTION_AT_REST']])]) 
        {
          script {
            def servers = readFile('servers.txt').trim().split("\\r?\\n")

            def control_ips = servers.collect { line ->
              def f = line.split(',')
              def role = f[4]
              def ip = f[3]
              (role == 'controlplane' || role == 'init') ? ip : null
            }.findAll { it != null }

            echo(message: "Control Plane IPs: ${control_ips}")

            def control_ips_json = control_ips.collect { "\"${it}\"" }.join(',')

            sh("""
              ansible-playbook --limit=controlplane[0] -i inventory.ini \
                ./ansible/stage2_controlplane.yml \
                --extra-vars='{
                  "mode":"init",
                  "controlplane_ips":[${control_ips_json}],
                  "token":"${K8S_TOKEN}",
                  "certificate_key":"${K8S_CERTIFICATE_KEY}",
                  "k8s_version":"${K8S_VERSION}",
                  "encryption_key":"${K8S_ENCRYPTION_AT_REST }"
                }'
              ansible-playbook --limit=controlplane[1:] -i inventory.ini \
                ./ansible/stage2_controlplane.yml \
                --extra-vars='{
                  "mode":"controlplane",
                  "controlplane_ips":[${control_ips_json}],
                  "token":"${K8S_TOKEN}",
                  "certificate_key":"${K8S_CERTIFICATE_KEY}",
                  "k8s_version":"${K8S_VERSION}",
                  "encryption_key":"${K8S_ENCRYPTION_AT_REST }"
                }'
              ansible-playbook --limit=workers -i inventory.ini \
                ./ansible/stage2_worker.yml \
                --extra-vars='{
                  "token":"${K8S_TOKEN}",
                  "certificate_key":"${K8S_CERTIFICATE_KEY}"
                }'
            """)
          }
        }
      }
    }
    stage('Deploy k8s Apps') {
      agent { label 'linux' }
      when {
        expression { !params.TEARDOWN }
      }
      steps {
        withInfisical(configuration: [infisicalCredentialId: 'infisical',infisicalEnvironmentSlug: 'prod',infisicalProjectSlug: 'homelab-b-h-sw'],
          infisicalSecrets: [infisicalSecret(includeImports: true, path: '/', secretValues: [[infisicalKey: 'K8S_TOKEN'],[infisicalKey: 'K8S_CERTIFICATE_KEY'],[infisicalKey: 'K8S_ENCRYPTION_AT_REST']])]) {
          script {
            sh("""
              ansible-playbook -i inventory.ini \
                ./ansible/k8s-apps/metallb.yml
            """)
          }
        }
      }
    }
  }
}
