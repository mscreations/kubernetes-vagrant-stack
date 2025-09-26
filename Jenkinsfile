pipeline {
    agent { label 'hyperv' }
    options {
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '30', numToKeepStr: '5'))
    }
    environment {
        VAGRANT_DOTFILE_PATH='D:\\Jenkins\\.vagrant'
        VAGRANT_FORCE_COLOR=1
        VAGRANT_INSTALL_LOCAL_PLUGINS=1
    }
    triggers {
        pollSCM('H/15 * * * *')   // poll every 15 minutes
    }
    parameters {
        string name: 'VAGRANT_EXTRA_ARGS', trim: true
        booleanParam 'UPDATE_BOX'
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
        stage('Update Vagrant Box') {
            when {
                expression { params.UPDATE_BOX }
            }
            steps {
                bat "vagrant box update"
            }
        }
        stage('Run Vagrant') {
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
                                [infisicalKey: 'CERT_EMAIL'], 
                                [infisicalKey: 'DOMAIN'], 
                                [infisicalKey: 'DHCP_SERVER']
                            ]
                        )
                    ]
                ) {
                    bat "vagrant up --provision $VAGRANT_EXTRA_ARGS"    // Ensure provisioners are rerun.
                }
            }
        }
    }
}
