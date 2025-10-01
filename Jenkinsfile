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
    // triggers {
    //     pollSCM('*/2 * * * *')
    // }
    parameters {
        string defaultValue: "1.34", name: 'K8S_VERSION', trim: true
        booleanParam 'TEARDOWN'
        string name: 'VAGRANT_EXTRA_ARGS', trim: true
        booleanParam 'UPDATE_BOX'
        string defaultValue: '172.29.125', name: 'NETWORK_PREFIX', trim: true
        string defaultValue: '192.168.0.0/16', name: 'POD_NETWORK', trim: true
        string defaultValue: 'mscreations/ubuntu2404', name: 'VAGRANT_BOX', trim: true
        string defaultValue: '3', name: 'CONTROLPLANE_NODES_COUNT', trim: true
        string defaultValue: '4', name: 'CONTROLPLANE_MAX_CPUS', trim: true
        string defaultValue: '4096', name: 'CONTROLPLANE_MAX_MEMORY', trim: true
        string defaultValue: '3', name: 'WORKER_NODES_COUNT', trim: true
        string defaultValue: '16', name: 'WORKER_MAX_CPUS', trim: true
        string defaultValue: '32768', name: 'WORKER_MAX_MEMORY', trim: true
    }
    stages {
        stage('Checkout') {
            agent { label 'hyperv' }
            steps {
                bat "git config --global core.autocrlf false"
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/split-workflow']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'WipeWorkspace']],
                    userRemoteConfigs: [[url: 'git@github.com:mscreations/kubernetes-vagrant-stack.git', credentialsId: 'Github']]
                ])
                
                powershell """
                    Copy-Item -Path '..\\..\\Kubernetes\\customize\\*' -Destination 'customize\\' -Recurse -Force
                """

                stash includes: '**', name: 'SourceFiles'
            }
        }
        stage('Generate Servers + Inventory') {
            agent { label 'linux' }
            steps {
                unstash 'SourceFiles'
                sh 'chmod +x ./scripts/generate_servers.sh'
                script {
                    def output = sh(script: './scripts/generate_servers.sh', returnStdout: true).trim()
                    writeFile file: 'servers.txt', text: output
                }
                archiveArtifacts artifacts: 'servers.txt,inventory.ini', fingerprint: true
                stash includes: 'servers.txt,inventory.ini', name: 'configFiles'
            }
        }
        stage('Prepare Jenkins SSH Key') {
            agent { label 'linux' }
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

                    // Ensure .ssh directory exists
                    sh """
                        mkdir -p "${sshDir}"
                        chmod 700 "${sshDir}"
                    """

                    // Generate key if missing
                    sh """
                        if [ ! -f "${keyFile}" ]; then
                            ssh-keygen -t rsa -b 4096 -f "${keyFile}" -N ""
                        fi
                    """

                    // Read public key into env variable
                    env.SSH_KEY = sh(
                        script: "cat ${keyFile}.pub",
                        returnStdout: true
                    ).trim()

                    // Update SSH config for servers in servers.txt
                    def servers = readFile('servers.txt').trim().split("\\r?\\n")
                    def sshConfigFile = "${sshDir}/config"

                    sh """
                        touch "${sshConfigFile}"
                        chmod 600 "${sshConfigFile}"
                    """

                    servers.each { line ->
                        def field = line.split(',')
                        def server = field[0]
                        sh """
                            # Remove old entry for host to avoid duplicates
                            sed -i '/Host ${server}/,+5d' "${sshConfigFile}"

                            # Add new entry
                            echo "Host ${server}" >> "${sshConfigFile}"
                            echo "    HostName ${server}" >> "${sshConfigFile}"
                            echo "    User vagrant" >> "${sshConfigFile}"
                            echo "    IdentityFile ${keyFile}" >> "${sshConfigFile}"
                            echo "    StrictHostKeyChecking no" >> "${sshConfigFile}"
                            echo "    UserKnownHostsFile /dev/null" >> "${sshConfigFile}"
                        """
                    }

                    echo "SSH key ready at ${keyFile}, SSH config updated."
                }
            }
        }
        stage('Check VM Status') {
            agent { label 'hyperv' }
            steps {
                unstash 'configFiles'

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

                        echo "VM ${name} status: ${status}"
                    }

                    if (allCreated) {
                        echo "All VMs exist, skipping vagrant up"
                        skipVagrant = true
                    }
                    env.SKIP_VAGRANT = skipVagrant.toString()
                }
            }
        }
        stage('Run Vagrant') {
            agent { label 'hyperv' }
            when {
                expression { env.SKIP_VAGRANT == 'false' }
            }
            steps {
                withInfisical(
                    configuration: [
                        infisicalCredentialId: 'infisical', 
                        infisicalEnvironmentSlug: 'prod', 
                        infisicalProjectSlug: 'homelab-b-h-sw', 
                        infisicalUrl: 'https://app.infisical.com'
                    ],
                    infisicalSecrets: [
                        infisicalSecret(
                            includeImports: true, path: '/', secretValues: [
                                [infisicalKey: 'DOMAIN_USER'], 
                                [infisicalKey: 'DOMAIN_PASSWORD'], 
                                [infisicalKey: 'DOMAIN'], 
                                [infisicalKey: 'DHCP_SERVER']
                            ]
                        )
                    ]
                ) {
                    bat "vagrant up $VAGRANT_EXTRA_ARGS"
                }
            }
        }
        stage('Skip Vagrant True') {
            agent { label 'linux' }
            when {
                expression { env.SKIP_VAGRANT == 'true' }
            }
            steps {
                echo "Running deployment..."
                // Add your deployment steps here
            }
        }
        stage('Provision Customizations') {
            agent { label 'linux' }
            steps {
                script {
                    sh """
                        chmod +x ./scripts/deploy_customizations.sh
                        ./scripts/deploy_customizations.sh
                    """
                }
            }
        }
        stage('Stage 1 Provision') {
            agent { label 'linux' }
            steps {
                withInfisical(
                    configuration: [
                        infisicalCredentialId: 'infisical', 
                        infisicalEnvironmentSlug: 'prod', 
                        infisicalProjectSlug: 'homelab-b-h-sw', 
                        infisicalUrl: 'https://app.infisical.com'
                    ],
                    infisicalSecrets: [
                        infisicalSecret(
                            includeImports: true, path: '/', secretValues: [
                                [infisicalKey: 'DOMAIN_PASSWORD'], 
                                [infisicalKey: 'DOMAIN'],
                                [infisicalKey: 'NEW_SSH_PASSWORD']
                            ]
                        )
                    ]
                ) {
                    script {
                        sh """
                            ansible-galaxy install -r ./ansible/requirements.yml -p /etc/ansible/roles --force
                            
                            ansible-playbook -i inventory.ini \
                                ./ansible/stage1.yml\
                                -e "new_ssh_password=${NEW_SSH_PASSWORD}" \
                                -e "domain_password=${DOMAIN_PASSWORD}" \
                                -e "domain=${DOMAIN}" \
                                -e "k8s_version=${K8S_VERSION}"
                        """
                    }
                }
            }
        }
    }
}
