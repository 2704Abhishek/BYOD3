pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        /* =========================
           Terraform Init & Plan
           ========================= */

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

        /* =========================
           Apply Approval
           ========================= */

        stage('Validate Apply') {
            when { branch 'dev' }
            steps {
                input {
                    message "Do you want to APPLY Terraform changes for DEV?"
                    ok "Apply"
                }
                echo 'Apply approved'
            }
        }

        /* =========================
           Apply + Capture Outputs
           ========================= */

        stage('Terraform Apply & Capture Outputs') {
            when { branch 'dev' }
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

                    echo "EC2 IP = ${env.INSTANCE_IP}"
                    echo "EC2 ID = ${env.INSTANCE_ID}"
                }
            }
        }

        /* =========================
           Dynamic Inventory
           ========================= */

        stage('Create Dynamic Inventory') {
            steps {
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/terraform_key.pem >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        /* =========================
           EC2 Health Check
           ========================= */

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

        /* =========================
           Splunk Install & Test
           ========================= */

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

        /* =========================
           Destroy Approval
           ========================= */

        stage('Validate Destroy') {
            steps {
                input {
                    message "Do you want to DESTROY the infrastructure?"
                    ok "Destroy"
                }
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

    /* =========================
       Post Build Cleanup
       ========================= */

    post {
        always {
            bat "if exist dynamic_inventory.ini del dynamic_inventory.ini"
        }

        failure {
            withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds'
            ]]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }

        aborted {
            withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds'
            ]]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }

        success {
            echo '✅ Pipeline completed successfully'
        }
    }
}
