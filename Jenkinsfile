pipeline {
    agent any

    tools {
        jdk 'JDK 21'
        maven 'Maven 3'
    }

    stages {
        stage('Clone') {
            steps {
                git branch: 'master', url: 'https://github.com/kimad-cy/Employee_Management'
            }
        }

        stage('Build & Test') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'mvn clean package'
                    } else {
                        bat 'mvn clean package'
                    }
                }
            }
        }
    }

    post {
        always {
            junit '**/target/surefire-reports/*.xml'
            archiveArtifacts artifacts: '**/target/*.war', allowEmptyArchive: true
        }
        success {
            echo '✅ Build succeeded!'
        }
        failure {
            echo '❌ Build failed!'
        }
    }
}
