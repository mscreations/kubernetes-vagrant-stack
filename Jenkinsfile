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
            agent { label 'linux' }
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/split-workflow']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'WipeWorkspace']],
                    userRemoteConfigs: [[url: 'git@github.com:mscreations/kubernetes-vagrant-stack.git', credentialsId: 'Github']]
                ])
                stash includes: '**', name: 'linuxSource'
            }
        }
        stage('Generate Servers + Inventory') {
            agent { label 'linux' }
            steps {

                sh 'chmod +x ./scripts/generate_servers.sh'
                script {
                    def output = sh(script: './scripts/generate_servers.sh', returnStdout: true).trim()
                    writeFile file: 'servers.txt', text: output
                }
                archiveArtifacts artifacts: 'servers.txt,inventory.ini', fingerprint: true
                stash includes: 'servers.txt,inventory.ini', name: 'configFiles'
            }
        }
        stage('Check VM Status') {
            agent { label 'hyperv' }
            steps {
                unstash 'linuxSource'
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
                            echo "All are NOT created"
                        }

                        echo "VM ${name} status: ${status}"
                    }

                    if (allCreated) {
                        currentBuild.description = "All VMs exist, skipping vagrant up"
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
                    bat "vagrant up --provision $VAGRANT_EXTRA_ARGS"    // Ensure provisioners are rerun.
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
    }
}
