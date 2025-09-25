pipeline {
    agent { label 'hyperv' }
    options {
        ansiColor('xterm')
    }
    environment {
        VAGRANT_DOTFILE_PATH='D:\\Jenkins\\.vagrant'
        VAGRANT_FORCE_COLOR=1
        VAGRANT_INSTALL_LOCAL_PLUGINS=1
                    
    }
    triggers {
        pollSCM('H/15 * * * *')   // poll every 15 minutes
    }
    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'WipeWorkspace']], // cleans workspace first
                    userRemoteConfigs: [[url: 'git@github.com:mscreations/kubernetes-vagrant-stack.git', credentialsId: 'Github']]
                ])
            }
        }
        stage('Populate customization directory') {
            steps {
                powershell """
                    Copy-Item -Path '..\\..\\Kubernetes\\customize\\*' -Destination 'customize\\' -Recurse -Force
                """
            }
        }
        stage('Run Vagrant') {
            steps {
                withInfisical(
                    configuration: [
                        infisicalCredentialId: 'infisical', 
                        infisicalEnvironmentSlug: 'dev', 
                        infisicalProjectSlug: 'homelab-b-h-sw', 
                        infisicalUrl: 'https://app.infisical.com'
                    ],
                    infisicalSecrets: [
                        infisicalSecret(
                            includeImports: true, path: '/', secretValues: [
                                [infisicalKey: 'DOMAIN_USER'], 
                                [infisicalKey: 'DOMAIN_PASSWORD'], 
                                [infisicalKey: 'CERT_EMAIL'], 
                                [infisicalKey: 'DOMAIN'], 
                                [infisicalKey: 'DHCP_SERVER'],
                                [infisicalKey: 'MASTER_MAX_CPUS'],
                                [infisicalKey: 'MASTER_MAX_MEMORY'],
                                [infisicalKey: 'MASTER_NODES_COUNT'],
                                [infisicalKey: 'NETWORK_PREFIX'],
                                [infisicalKey: 'POD_NETWORK'],
                                [infisicalKey: 'VAGRANT_BOX'],
                                [infisicalKey: 'WORKER_MAX_CPUS'],
                                [infisicalKey: 'WORKER_MAX_MEMORY'],
                                [infisicalKey: 'WORKER_NODES_COUNT']
                            ]
                        )
                    ]
                ) {
                    bat "vagrant up --provision"    // Ensure provisioners are rerun.
                }
            }
        }
    }
}
