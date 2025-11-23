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
                    
                    # Clean up any existing instances
                    minikube stop 2>&1 | Write-Host
                    minikube delete 2>&1 | Write-Host
                    
                    # Start Minikube with appropriate memory settings
                    Write-Host "Starting Minikube with 2GB memory..."
                    minikube start --driver=docker --memory=2048 --cpus=2
                    
                    # Configure kubectl context
                    kubectl config use-context minikube
                    
                    # Set up Docker to use Minikube's daemon
                    $envCommand = minikube docker-env
                    if ($envCommand) {
                        Invoke-Expression $envCommand
                        Write-Host "Docker environment configured for Minikube"
                    } else {
                        Write-Host "Warning: Could not configure Docker environment"
                    }
                    
                    # Wait for cluster to be ready
                    Write-Host "Waiting for cluster to be ready..."
                    Start-Sleep -Seconds 30
                    
                    # Verify cluster status
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

        stage('Build Docker Images') {
            steps {
                script {
                    // Build backend image
                    dir('backend') {
                        bat 'docker build -t employee_management-backend:latest .'
                    }
                    
                    // Build frontend image if frontend exists
                    if (fileExists('frontend')) {
                        dir('frontend') {
                            bat 'docker build -t employee_management-frontend:latest .'
                        }
                    }
                    
                    // Push to Docker Hub
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

        stage('Load Images to Minikube') {
            steps {
                powershell '''
                    Write-Host "=== Loading Docker Images into Minikube ==="
                    
                    # Load images into Minikube
                    minikube image load employee_management-backend:latest
                    minikube image load mysql:8
                    
                    if (Test-Path "frontend") {
                        minikube image load employee_management-frontend:latest
                    }
                    
                    Write-Host "Images loaded into Minikube"
                '''
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
                        script {
                            timeout(time: 5, unit: 'MINUTES') {
                                bat 'kubectl wait --for=condition=available deployment/backend --timeout=300s'
                                bat 'kubectl wait --for=condition=available deployment/mysql --timeout=300s'
                                
                                if (fileExists('frontend')) {
                                    bat 'kubectl wait --for=condition=available deployment/frontend --timeout=300s'
                                }
                            }
                        }
                        
                        // Show detailed status
                        bat 'kubectl get pods,services,deployments'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    // Check pod status
                    bat 'kubectl get pods -o wide'
                    
                    // Check logs for any issues
                    bat 'kubectl logs -l app=backend --tail=20 || echo "No backend logs yet"'
                    bat 'kubectl logs -l app=mysql --tail=20 || echo "No MySQL logs yet"'
                    
                    if (fileExists('frontend')) {
                        bat 'kubectl logs -l app=frontend --tail=20 || echo "No frontend logs yet"'
                    }
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
