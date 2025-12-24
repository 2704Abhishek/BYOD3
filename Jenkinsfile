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

        /* =========================
           TASK 3 (OLD): INIT & PLAN
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
           TASK 5 (OLD): APPLY GATE
           ========================= */

        stage('Validate Apply') {
            when {
                branch 'dev'
            }
            steps {
                input {
                    message "Do you want to apply Terraform changes for DEV?"
                    ok "Apply"
                }
                echo 'Apply approved'
            }
        }

        /* =========================
           TASK 1 (NEW): APPLY + OUTPUT
           ========================= */

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

        /* =========================
           TASK 2: DYNAMIC INVENTORY
           ========================= */

        stage('Create Dynamic Inventory') {
            steps {
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        /* =========================
           TASK 3: EC2 HEALTH CHECK
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
           TASK 4: SPLUNK INSTALL & TEST
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
           TASK 5: DESTROY GATE
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
       POST BUILD CLEANUP
       ========================= */

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
