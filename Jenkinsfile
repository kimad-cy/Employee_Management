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

        stage('Start Minikube') {
            steps {
                powershell '''
                    Write-Host "=== Starting Minikube Setup ==="
                    
                    # Check if Minikube is running
                    Write-Host "Checking Minikube status..."
                    minikube status
                    
                    # Stop and delete existing cluster
                    Write-Host "Cleaning up existing Minikube cluster..."
                    minikube stop
                    minikube delete
                    
                    # Start fresh Minikube cluster
                    Write-Host "Starting new Minikube cluster..."
                    minikube start --driver=docker --force
                    
                    # Configure kubectl context
                    Write-Host "Setting kubectl context..."
                    kubectl config use-context minikube
                    
                    # Wait for cluster to be ready
                    Write-Host "Waiting for cluster components..."
                    Start-Sleep -Seconds 30
                    
                    # Verify cluster status
                    Write-Host "Cluster information:"
                    kubectl cluster-info
                    
                    Write-Host "Node status:"
                    kubectl get nodes
                    
                    Write-Host "=== Minikube Setup Complete ==="
                '''
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
            when { 
                expression { 
                    // Only run if frontend directory exists
                    fileExists('frontend') 
                } 
            }
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

        stage('Build Docker Images') {
            steps {
                script {
                    // Build backend image
                    dir('backend') {
                        bat "docker build -t employee_management-backend:latest ."
                    }

                    // Build frontend image (only if frontend exists)
                    if (fileExists('frontend')) {
                        dir('frontend') {
                            bat "docker build -t employee_management-frontend:latest ."
                        }
                    }

                    // Push to Docker Hub
                    withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        bat "docker login -u %DOCKER_USER% -p %DOCKER_PASS%"
                        bat "docker tag employee_management-backend:latest ${DOCKERHUB_USER}/employee_management-backend:latest"
                        bat "docker push ${DOCKERHUB_USER}/employee_management-backend:latest"
                        
                        if (fileExists('frontend')) {
                            bat "docker tag employee_management-frontend:latest ${DOCKERHUB_USER}/employee_management-frontend:latest"
                            bat "docker push ${DOCKERHUB_USER}/employee_management-frontend:latest"
                        }
                    }
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                script {
                    // Verify Minikube is accessible
                    bat 'kubectl cluster-info'
                    
                    dir('k8s') {
                        // Apply all Kubernetes manifests
                        bat 'kubectl apply -f .'
                        
                        // Wait for deployments to be ready
                        bat 'kubectl rollout status deployment/backend-deployment --timeout=300s'
                        
                        if (fileExists('frontend')) {
                            bat 'kubectl rollout status deployment/frontend-deployment --timeout=300s'
                        }
                        
                        // Show deployment status
                        bat 'kubectl get pods,services'
                    }
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'backend/target/*.jar', fingerprint: true
                // Only archive frontend if it exists
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
            echo '✅ Build, Docker & Minikube deployment succeeded!'
            script {
                // Show final status
                bat 'kubectl get pods,services'
            }
        }
        failure {
            echo '❌ Build, Docker or Minikube deployment failed!'
            script {
                // Debug information
                bat 'kubectl get pods,services'
                bat 'kubectl describe pods'
            }
        }
    }
}
