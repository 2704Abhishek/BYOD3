pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS = '-no-color'
        AWS_CREDS = credentials('aws-creds')
        SSH_CRED_ID = 'aws-deployer-ssh-key1'
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Initialization') {
            steps {
                sh 'terraform init'
                sh "cat ${env.BRANCH_NAME}.tfvars"
            }
        }

        stage('Terraform Plan') {
            steps {
                sh "terraform plan -var-file=${env.BRANCH_NAME}.tfvars"
            }
        }

        stage('Validate Apply') {
            when {
                branch 'dev'
            }
            input {
                message "Do you want to apply Terraform changes for DEV?"
                ok "Apply"
            }
            steps {
                echo 'Approval received for DEV branch'
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully'
        }
        failure {
            echo '❌ Pipeline failed'
        }
    }
}
