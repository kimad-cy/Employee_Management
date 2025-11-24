pipeline {
    agent any

    tools {
        jdk 'JDK 21'
        maven 'Maven 3'
        nodejs 'Node 18'
    }

    environment {
        DOCKERHUB_CREDENTIALS = 'dockerhub-credentials'
        DOCKERHUB_USER = 'kimadcy'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
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
                script {
                    if (fileExists('frontend')) {
                        dir('frontend') {
                            bat 'npm install'
                            bat 'npm run build'
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    // Backend image
                    dir('backend') {
                        bat 'docker build -t employee_management-backend:latest .'
                    }

                    // Frontend image if exists
                    if (fileExists('frontend')) {
                        dir('frontend') {
                            bat 'docker build -t employee_management-frontend:latest .'
                        }
                    }
                }
            }
        }

        stage('Push Docker Images to Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: "${DOCKERHUB_CREDENTIALS}", 
                        usernameVariable: 'DOCKER_USER', 
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        bat 'docker login -u %DOCKER_USER% -p %DOCKER_PASS%'
                        bat 'docker tag employee_management-backend:latest %DOCKER_USER%/employee_management-backend:latest'
                        bat 'docker push %DOCKER_USER%/employee_management-backend:latest'

                        if (fileExists('frontend')) {
                            bat 'docker tag employee_management-frontend:latest %DOCKER_USER%/employee_management-frontend:latest'
                            bat 'docker push %DOCKER_USER%/employee_management-frontend:latest'
                        }
                    }
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                dir('k8s') {
                    bat 'kubectl apply -f .'
                    }

                    bat 'kubectl get pods,services,deployments'
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'backend/target/*.jar', fingerprint: true
                script {
                    if (fileExists('frontend/build')) {
                        archiveArtifacts artifacts: 'frontend/build/**', fingerprint: true
                    }
                }
            }
        }

    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
            bat 'kubectl get pods,services,deployments'
        }
    }
}
