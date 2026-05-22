pipeline {
    agent any
    
    // =========================================
    // ENVIRONMENT VARIABLES
    // =========================================
    environment {
        AWS_REGION        = 'ap-south-1'
        AWS_ACCOUNT_ID    = credentials('AWS_ACCOUNT_ID')
        ECR_REGISTRY      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO          = 'digital-assistant'
        CLUSTER_NAME      = 'digital-assistant-cluster'
        
        IMAGE_TAG         = "${BUILD_NUMBER}"
        IMAGE_NAME        = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        
        SONAR_PROJECT_KEY = 'digital-assistant'
    }

    // =========================================
    // PIPELINE OPTIONS
    // =========================================
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    // =========================================
    // TRIGGERS
    // =========================================
    triggers {
        githubPush() 
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code from branch: ${env.BRANCH_NAME}"
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo "Building Maven project..."
                sh 'mvn clean package -DskipTests --batch-mode'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }

        stage('Security Scan') {
            parallel {
                stage('Trivy FS Scan') {
                    steps {
                        sh 'trivy fs --format table --output trivy-report.txt .'
                    }
                    post {
                        always { archiveArtifacts artifacts: 'trivy-report.txt' }
                    }
                }
                stage('Gitleaks Scan') {
                    steps {
                        sh 'gitleaks detect --source . --report-format json --report-path gitleaks-report.json --exit-code 0'
                    }
                    post {
                        always { archiveArtifacts artifacts: 'gitleaks-report.json' }
                    }
                }
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test --batch-mode'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn sonar:sonar \
                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                          -Dsonar.sources=src/main/java \
                          -Dsonar.tests=src/test/java \
                          -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        
                        docker build -t ${IMAGE_NAME} .
                        docker tag ${IMAGE_NAME} ${ECR_REGISTRY}/${ECR_REPO}:latest
                        
                        docker push ${IMAGE_NAME}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    trivy image --format table --output trivy-image-report.txt \
                      --severity HIGH,CRITICAL ${IMAGE_NAME}
                '''
            }
            post {
                always { archiveArtifacts artifacts: 'trivy-image-report.txt' }
            }
        }

        stage('Deploy to EKS') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
                        
                        kubectl apply -f k8s/app/ || echo "Warning: Some manifests may already exist"
                        
                        kubectl set image deployment/digital-assistant digital-assistant=${IMAGE_NAME}
                        kubectl annotate deployment/digital-assistant kubernetes.io/change-cause="Build:${BUILD_NUMBER}" --overwrite
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        kubectl rollout status deployment/digital-assistant --timeout=300s
                        echo "===== PODS ====="
                        kubectl get pods -o wide
                        echo "===== SERVICES ====="
                        kubectl get svc
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline succeeded! Build #${BUILD_NUMBER}"
            emailext(
                subject: "✅ SUCCESS: Digital Assistant Build #${BUILD_NUMBER}",
                body: 'Build succeeded. Image: ${IMAGE_NAME}',
                to: 'your-email@gmail.com'
            )
        }
        failure {
            echo "❌ Pipeline failed!"
            emailext(
                subject: "❌ FAILED: Digital Assistant Build #${BUILD_NUMBER}",
                body: 'Build failed. Check Jenkins: ${BUILD_URL}',
                to: 'your-email@gmail.com'
            )
        }
        always {
            cleanWs()
        }
    }
}
