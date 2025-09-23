pipeline {
    agent { label 'hyperv' }
    options {
        ansiColor('xterm')
    }
    environment {
        VAGRANT_DOTFILE_PATH='D:\\Jenkins\\.vagrant'
        VAGRANT_FORCE_COLOR=1
                    
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
        stage('Inject secrets.rb') {
            steps {
                withCredentials([file(credentialsId: 'secrets.rb', variable: 'SECRETS_FILE')]) {
                    // Copy the credential file into the workspace as secrets.rb
                    bat """
                        copy "%SECRETS_FILE%" "%WORKSPACE%\\secrets.rb"
                    """
                }
            }
        }
        stage('Run Vagrant') {
            steps {
                bat "vagrant up"
            }
        }
    }
}
