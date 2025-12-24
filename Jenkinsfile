pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        // Task 3: Required for AWS CLI commands to work
        AWS_DEFAULT_REGION = 'us-east-1' 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --- TASK 1: Provisioning & Output Capture (20 Marks) ---
        stage('Terraform Apply & Capture') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "terraform init"
                    bat "terraform apply -auto-approve -var-file=%BRANCH_NAME%.tfvars"
                    
                    script {
                        // Capture outputs and strip command echo/newlines for Windows
                        def ipRaw = bat(script: "terraform output -raw instance_public_ip", returnStdout: true).trim()
                        def idRaw = bat(script: "terraform output -raw instance_id", returnStdout: true).trim()
                        
                        // Extract only the final value (the IP/ID)
                        env.INSTANCE_IP = ipRaw.split('\r?\n')[-1]
                        env.INSTANCE_ID = idRaw.split('\r?\n')[-1]
                    }
                }
                echo "Captured IP: ${env.INSTANCE_IP}"
                echo "Captured ID: ${env.INSTANCE_ID}"
            }
        }

        // --- TASK 2: Dynamic Inventory Management (20 Marks) ---
        stage('Create Dynamic Inventory') {
            steps {
                // Task 2: Create a file formatted for Ansible
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/terraform_key.pem >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        // --- TASK 3: AWS Health Status Verification (20 Marks) ---
        stage('Wait for EC2 Health') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    // Task 3: Use AWS CLI to poll health checks
                    bat "aws ec2 wait instance-status-ok --instance-ids %INSTANCE_ID%"
                }
            }
        }

        // --- TASK 4: Splunk Installation & Testing (20 Marks) ---
        stage('Install & Test Splunk') {
            steps {
                script {
                    // Task 4: Execute Ansible via WSL because it is not installed on Windows
                    echo "Executing Ansible playbooks via WSL..."
                    
                    // Task 4.1: Run Splunk installation
                    bat "wsl ansible-playbook -i dynamic_inventory.ini playbooks/splunk.yml"
                    
                    // Task 4.2: Verify service is reachable
                    bat "wsl ansible-playbook -i dynamic_inventory.ini playbooks/test-splunk.yml"
                }
            }
        }

        // --- TASK 5: Infrastructure Destruction (20 Marks) ---
        stage('Validate Destroy') {
            steps {
                // Task 5.1: Manual approval gate
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
            // Task 5.2: Cleanup inventory file
            bat "if exist dynamic_inventory.ini del dynamic_inventory.ini"
        }
        failure {
            // Task 5.3: Automated trigger on failure
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }
        aborted {
            // Task 5.3: Automated trigger on abort
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }
    }
}