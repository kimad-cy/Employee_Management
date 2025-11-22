pipeline {
    agent any

    tools {
        jdk 'JDK 21'
        maven 'Maven 3'
        nodejs 'Node 18' // Add Node.js tool if you have it configured in Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/kimad-cy/Employee_Management.git'
            }
        }

        stage('Build Backend') {
            steps {
                dir('backend') {
                    bat 'mvn clean package'
                }
            }
        }

        stage('Build Frontend') {
            steps {
                dir('frontend') {
                    // Install dependencies and build
                    bat 'npm install'
                    bat 'npm run build'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('backend') {
                    withSonarQubeEnv('LocalSonar') { // Name of SonarQube server in Jenkins
                        withCredentials([string(credentialsId: 'SONAR_AUTH_TOKEN', variable: 'SONAR_TOKEN')]) {
                            bat "mvn sonar:sonar -Dsonar.login=%SONAR_TOKEN%"
                        }
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'backend/target/*.jar', fingerprint: true
                archiveArtifacts artifacts: 'frontend/build/**', fingerprint: true
            }
        }
    }

    post {
        success {
            echo '✅ Build succeeded!'
        }
        failure {
            echo '❌ Build failed!'
        }
    }
}
