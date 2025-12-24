pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        AWS_DEFAULT_REGION = 'us-east-1' 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --- TASK 1: Provisioning & Output Capture ---
        stage('Terraform Apply & Capture') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "terraform init"
                    bat "terraform apply -auto-approve -var-file=%BRANCH_NAME%.tfvars"
                    
                    script {
                        def ipRaw = bat(script: "terraform output -raw instance_public_ip", returnStdout: true).trim()
                        def idRaw = bat(script: "terraform output -raw instance_id", returnStdout: true).trim()
                        
                        env.INSTANCE_IP = ipRaw.split('\r?\n')[-1]
                        env.INSTANCE_ID = idRaw.split('\r?\n')[-1]
                    }
                }
            }
        }

        // --- TASK 2: Dynamic Inventory Management ---
        stage('Create Dynamic Inventory') {
            steps {
                // We point the key path to the Linux home directory where your key actually is
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user ansible_ssh_private_key_file=/home/shilu/.ssh/terraform_key.pem >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        // --- TASK 3: AWS Health Status Verification ---
        stage('Wait for EC2 Health') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "aws ec2 wait instance-status-ok --instance-ids %INSTANCE_ID%"
                }
            }
        }

        // --- TASK 4: Splunk Installation & Testing ---
        stage('Install & Test Splunk') {
            steps {
                script {
                    // Task 4: Runs Ansible core 2.19.4 inside WSL
                    bat "wsl ansible-playbook -i dynamic_inventory.ini playbooks/splunk.yml"
                    bat "wsl ansible-playbook -i dynamic_inventory.ini playbooks/test-splunk.yml"
                }
            }
        }

        // --- TASK 5: Destruction ---
        stage('Validate Destroy') {
            steps {
                input message: "Do you want to DESTROY the infrastructure?", ok: "Destroy"
            }
        }

        stage('Terraform Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
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
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }
    }
}