pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS = '-no-color'
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Initialization') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    bat 'terraform init'
                    bat 'type %BRANCH_NAME%.tfvars'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    bat "terraform plan -var-file=%BRANCH_NAME%.tfvars"
                }
            }
        }

        stage('Validate Apply') {
            when {
                branch 'dev'
            }
            steps {
                input message: 'Do you want to apply Terraform changes for DEV?', ok: 'Apply'
                echo 'Apply approved'
            }
        }

        stage('Terraform Apply & Capture Outputs') {
            when {
                branch 'dev'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {

                    bat "terraform apply -auto-approve -var-file=%BRANCH_NAME%.tfvars"

                    script {
                        env.INSTANCE_IP = bat(
                            script: 'terraform output -raw instance_public_ip',
                            returnStdout: true
                        ).trim()

                        env.INSTANCE_ID = bat(
                            script: 'terraform output -raw instance_id',
                            returnStdout: true
                        ).trim()
                    }

                    echo "EC2 IP: ${env.INSTANCE_IP}"
                    echo "EC2 ID: ${env.INSTANCE_ID}"
                }
            }
        }

        stage('Create Dynamic Inventory') {
            steps {
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        stage('Wait for EC2 Health') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    bat "aws ec2 wait instance-status-ok --instance-ids %INSTANCE_ID%"
                }
            }
        }

        stage('Install Splunk') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/splunk.yml',
                    inventory: 'dynamic_inventory.ini'
                )
            }
        }

        stage('Test Splunk') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/test-splunk.yml',
                    inventory: 'dynamic_inventory.ini'
                )
            }
        }

        stage('Validate Destroy') {
            steps {
                input message: 'Do you want to DESTROY the infrastructure?', ok: 'Destroy'
            }
        }

        stage('Terraform Destroy') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
                }
            }
        }
    }

    post {
        always {
            bat "if exist dynamic_inventory.ini del dynamic_inventory.ini"
        }
        failure {
            bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
        }
        aborted {
            bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
        }
        success {
            echo '✅ Pipeline completed successfully'
        }
    }
}
