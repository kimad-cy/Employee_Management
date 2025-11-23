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
            when { expression { false } }
            steps {
                dir('frontend') {
                    bat 'npm install'
                    bat 'npm run build'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('backend') {
                    withSonarQubeEnv('LocalSonar') {
                        withCredentials([string(credentialsId: 'SONAR_AUTH_TOKEN', variable: 'SONAR_TOKEN')]) {
                            bat "mvn sonar:sonar -Dsonar.login=%SONAR_TOKEN%"
                        }
                    }
                }
            }
        }

        stage('Configure Minikube Docker') {
            steps {
                bat "@FOR /f \"tokens=*\" %i IN ('minikube docker-env --shell cmd') DO @%i"
            }
        }


        stage('Build Docker Images') {
            steps {
                script {
                    // Build backend image
                    dir('backend') {
                        bat "docker build -t employee_management-backend:latest ."
                    }

                    // Build frontend image
                    dir('frontend') {
                        bat "docker build -t employee_management-frontend:latest ."
                    }

                    // Optional: push to Docker Hub
                    withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        bat "docker login -u %DOCKER_USER% -p %DOCKER_PASS%"
                        bat "docker tag employee_management-backend:latest ${DOCKERHUB_USER}/employee_management-backend:latest"
                        bat "docker tag employee_management-frontend:latest ${DOCKERHUB_USER}/employee_management-frontend:latest"
                        bat "docker push ${DOCKERHUB_USER}/employee_management-backend:latest"
                        bat "docker push ${DOCKERHUB_USER}/employee_management-frontend:latest"
                    }
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                dir('k8s') {
                    // Apply Kubernetes manifests
                    bat 'kubectl apply -f backend-deployment.yaml'
                    bat 'kubectl apply -f backend-service.yaml'
                    bat 'kubectl apply -f frontend-deployment.yaml'
                    bat 'kubectl apply -f frontend-service.yaml'

                    // Optional: check pods
                    bat 'kubectl get pods'
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'backend/target/*.jar', fingerprint: true
                archiveArtifacts artifacts: 'frontend/build/**', fingerprint: true
            }
        }
    }

    post {
        success {
            echo '✅ Build, Docker & Minikube deployment succeeded!'
        }
        failure {
            echo '❌ Build, Docker or Minikube deployment failed!'
        }
    }
}
