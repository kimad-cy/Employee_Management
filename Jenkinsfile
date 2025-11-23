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
                    Write-Host "=== Starting Minikube ==="
                    # Stop and clean up any existing instance
                    minikube stop
                    minikube delete
                    
                    # Start fresh Minikube cluster
                    minikube start --driver=docker --force --memory=4096 --cpus=2
                    kubectl config use-context minikube
                    
                    # Set up Docker to use Minikube's daemon
                    minikube docker-env | Invoke-Expression
                    
                    # Wait for cluster to be ready
                    Start-Sleep -Seconds 20
                    kubectl cluster-info
                    kubectl get nodes
                    Write-Host "=== Minikube Ready ==="
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

        stage('Build Docker Images in Minikube') {
            steps {
                powershell '''
                    # Ensure we're using Minikube's Docker daemon
                    minikube docker-env | Invoke-Expression
                    Write-Host "=== Building Docker Images in Minikube ==="
                '''
                
                script {
                    // Build backend image using Minikube's Docker daemon
                    dir('backend') {
                        bat 'docker build -t employee_management-backend:latest .'
                    }
                    
                    // Build frontend image if frontend exists
                    if (fileExists('frontend')) {
                        dir('frontend') {
                            bat 'docker build -t employee_management-frontend:latest .'
                        }
                    }
                    
                    // Pull MySQL image
                    bat 'docker pull mysql:8'
                    
                    // Push to Docker Hub (optional - for backup/registry)
                    withCredentials([usernamePassword(
                        credentialsId: "${DOCKERHUB_CREDENTIALS}", 
                        usernameVariable: 'DOCKER_USER', 
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        bat 'docker login -u %DOCKER_USER% -p %DOCKER_PASS%'
                        bat 'docker tag employee_management-backend:latest ${DOCKERHUB_USER}/employee_management-backend:latest'
                        bat 'docker push ${DOCKERHUB_USER}/employee_management-backend:latest'
                        
                        if (fileExists('frontend')) {
                            bat 'docker tag employee_management-frontend:latest ${DOCKERHUB_USER}/employee_management-frontend:latest'
                            bat 'docker push ${DOCKERHUB_USER}/employee_management-frontend:latest'
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
                        
                        // Wait for deployments to be ready with longer timeouts
                        script {
                            timeout(time: 5, unit: 'MINUTES') {
                                bat 'kubectl rollout status deployment/backend --timeout=300s'
                                bat 'kubectl rollout status deployment/mysql --timeout=300s'
                                
                                if (fileExists('frontend')) {
                                    bat 'kubectl rollout status deployment/frontend --timeout=300s'
                                }
                            }
                        }
                        
                        // Show detailed status
                        bat 'kubectl get pods,services,deployments'
                        bat 'kubectl get ingress || echo "No ingress found"'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    // Wait a bit for services to stabilize
                    bat 'timeout 30'
                    
                    // Check pod status
                    bat 'kubectl get pods -o wide'
                    
                    // Check logs for any issues
                    bat 'kubectl logs -l app=backend --tail=50 || echo "No backend logs yet"'
                    bat 'kubectl logs -l app=mysql --tail=50 || echo "No MySQL logs yet"'
                    
                    if (fileExists('frontend')) {
                        bat 'kubectl logs -l app=frontend --tail=50 || echo "No frontend logs yet"'
                    }
                    
                    // Describe pods if any are not running
                    bat 'kubectl describe pods || echo "Cannot describe pods"'
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
            echo '✅ Build, Docker & Minikube deployment succeeded!'
            script {
                // Show final status
                bat 'kubectl get pods,services'
                bat 'echo "Deployment completed successfully!"'
                
                // Get Minikube service URLs
                bat 'minikube service list || echo "Cannot get service list"'
            }
        }
        failure {
            echo '❌ Build, Docker or Minikube deployment failed!'
            script {
                // Extensive debugging information
                bat 'kubectl get pods,services,deployments'
                bat 'kubectl describe pods'
                bat 'kubectl get events --sort-by=.lastTimestamp'
                
                // Logs from all containers
                bat 'kubectl logs -l app=backend --prefix=true || echo "No backend logs"'
                bat 'kubectl logs -l app=mysql --prefix=true || echo "No MySQL logs"'
                
                if (fileExists('frontend')) {
                    bat 'kubectl logs -l app=frontend --prefix=true || echo "No frontend logs"'
                }
            }
        }
        always {
            // Always archive test results if they exist
            junit 'backend/target/surefire-reports/*.xml'
            
            // Cleanup or final status
            bat 'echo "=== Pipeline Execution Complete ==="'
        }
    }
}
