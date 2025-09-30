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
    }
    triggers {
        pollSCM('*/2 * * * *')
    }
    parameters {
        string defaultValue: "1.34", name: 'K8S_VERSION', trim: true
        booleanParam 'TEARDOWN'
        string name: 'VAGRANT_EXTRA_ARGS', trim: true
        booleanParam 'UPDATE_BOX'
        string defaultValue: '172.29.125', name: 'NETWORK_PREFIX', trim: true
        string defaultValue: '192.168.0.0/16', name: 'POD_NETWORK', trim: true
        string defaultValue: 'mscreations/ubuntu2404', name: 'VAGRANT_BOX', trim: true
        string defaultValue: '3', name: 'MASTER_NODES_COUNT', trim: true
        string defaultValue: '4', name: 'MASTER_MAX_CPUS', trim: true
        string defaultValue: '4096', name: 'MASTER_MAX_MEMORY', trim: true
        string defaultValue: '0', name: 'WORKER_NODES_COUNT', trim: true
        string defaultValue: '16', name: 'WORKER_MAX_CPUS', trim: true
        string defaultValue: '32768', name: 'WORKER_MAX_MEMORY', trim: true
    }
    stages {
        stage('Generate Token') {
            when {
                expression { !params.TEARDOWN }
            }
            agent { label 'linux' }   // run this stage on your Linux agent
            steps {
                script {
                    def token = sh(
                        script: "tr -dc 'a-z0-9' </dev/urandom | head -c6 && echo -n '.' && tr -dc 'a-z0-9' </dev/urandom | head -c16",
                        returnStdout: true
                    ).trim()
                    echo "Generated token: ${token}"
                    env.RANDOM_TOKEN = token
                    def certificate_key = sh(
                        script: "openssl rand -hex 32"
                        returnStdout: true
                    ).trim()
                    echo "Generated certificate key: ${certifcate_key}"
                    env.CERTIFICATE_KEY = certificate_key
                }
            }
        }
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/dev']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'WipeWorkspace']], // cleans workspace first
                    userRemoteConfigs: [[url: 'git@github.com:mscreations/kubernetes-vagrant-stack.git', credentialsId: 'Github']]
                ])
            }
        }
        stage('Populate customization directory') {
            when {
                expression { !params.TEARDOWN }
            }
            steps {
                powershell """
                    Copy-Item -Path '..\\..\\Kubernetes\\customize\\*' -Destination 'customize\\' -Recurse -Force
                """
            }
        }
        stage('Update Vagrant Box') {
            when {
                expression { !params.TEARDOWN && params.UPDATE_BOX }
            }
            steps {
                bat "vagrant box update"
            }
        }
        stage('Run Vagrant') {
            when {
                expression { !params.TEARDOWN }
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
        stage('Ensure Pull Request') {
            agent { label 'linux' }
            when {
                allOf {
                    changeset "**/*"
                    expression { !params.TEARDOWN }
                }
            }
            steps {
                withCredentials([string(credentialsId: 'GithubToken', variable: 'GITHUB_TOKEN')]) {
                    sh '''
                        set -e
                        
                        existing_pr=$(gh pr list --base main --head dev --json number --jq '.[0].number')

                        if [ -n "$existing_pr" ]; then
                          echo "PR #$existing_pr exists. Commenting..."
                          gh pr comment $existing_pr --body "✅ Jenkins pipeline succeeded for commit $(git rev-parse --short HEAD)"
                        else
                          echo "No PR found. Creating a new one..."
                          gh pr create \
                            --base main \
                            --head dev \
                            --title "Promote dev to main" \
                            --body "Automated PR created by Jenkins after successful pipeline run."
                        fi
                    '''
                }
            }
        }
        stage('Teardown') {
            when {
                expression { params.TEARDOWN }
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
                    bat """
                        set MASTER_NODES_COUNT=3
                        set WORKER_NODES_COUNT=3
                        vagrant destroy -f
                    """
                }
            }
        }
    }
}
