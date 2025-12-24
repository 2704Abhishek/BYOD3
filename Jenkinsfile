pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        // Using credentials at a higher level reduces code duplication
        AWS_CREDS        = credentials('aws-creds') 
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "terraform init"
                    bat "terraform plan -var-file=%BRANCH_NAME%.tfvars"
                }
            }
        }

        stage('Validate Apply') {
            when { branch 'dev' }
            steps {
                input message: "Do you want to APPLY Terraform changes for DEV?", ok: "Apply"
            }
        }

        stage('Terraform Apply & Capture') {
            when { branch 'dev' }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "terraform apply -auto-approve -var-file=%BRANCH_NAME%.tfvars"
                    
                    script {
                        // Capture stdout while suppressing the command echo in the result
                        def ip = bat(script: "terraform output -raw instance_public_ip", returnStdout: true).trim()
                        def id = bat(script: "terraform output -raw instance_id", returnStdout: true).trim()
                        
                        // Clean Windows-specific output (sometimes includes the command itself)
                        env.INSTANCE_IP = ip.split('\r?\n')[-1]
                        env.INSTANCE_ID = id.split('\r?\n')[-1]
                    }
                    
                    echo "EC2 IP = ${env.INSTANCE_IP}"
                    echo "EC2 ID = ${env.INSTANCE_ID}"
                }
            }
        }

        stage('Create Dynamic Inventory') {
            when { branch 'dev' }
            steps {
                // Ensure variables are expanded correctly in the bat shell
                bat """
                echo [web] > dynamic_inventory.ini
                echo %INSTANCE_IP% ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/terraform_key.pem >> dynamic_inventory.ini
                """
                bat "type dynamic_inventory.ini"
            }
        }

        stage('Wait for EC2 Health') {
            when { branch 'dev' }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    bat "aws ec2 wait instance-status-ok --instance-ids %INSTANCE_ID%"
                }
            }
        }

        stage('Install & Test Splunk') {
            when { branch 'dev' }
            steps {
                ansiblePlaybook(playbook: 'playbooks/splunk.yml', inventory: 'dynamic_inventory.ini')
                ansiblePlaybook(playbook: 'playbooks/test-splunk.yml', inventory: 'dynamic_inventory.ini')
            }
        }

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
        
        // Combine failure and aborted to reduce repetition
        failure {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                bat "terraform destroy -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }
        
        success {
            echo '✅ Pipeline completed successfully'
        }
    }
}