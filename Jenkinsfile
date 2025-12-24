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
                bat 'terraform init'
                bat 'type %BRANCH_NAME%.tfvars'
            }
        }

        stage('Terraform Plan') {
            steps {
                bat "terraform plan -var-file=%BRANCH_NAME%.tfvars"
            }
        }

        stage('Validate Apply') {
            when {
                branch 'dev'
            }
            input {
                message "Apply Terraform changes for DEV?"
                ok "Apply"
            }
            steps {
                echo 'Approval granted'
            }
        }

        stage('Terraform Apply') {
            when {
                branch 'dev'
            }
            steps {
                bat "terraform apply -auto-approve -var-file=%BRANCH_NAME%.tfvars"
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully'
        }
        failure {
            echo '❌ Pipeline failed'
        }
    }
}

// End of Jenkinsfile