// ============================================================
// bankapp Manual Rollback Pipeline
// ============================================================

pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['prod', 'dev'],
            description: 'Environment to rollback'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Build number to rollback to (prod: 42, dev: dev-42)'
        )
    }

    environment {
        AWS_REGION     = 'ap-south-1'
        AWS_ACCOUNT_ID = credentials('AWS_ACCOUNT_ID')
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        PROD_CLUSTER   = 'bankapp-prod-cluster'
        DEV_CLUSTER    = 'bankapp-dev-cluster'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
    }

    stages {

        stage('Validate Input') {
            steps {
                script {
                    if (!params.IMAGE_TAG?.trim()) {
                        error "❌ IMAGE_TAG is required! Enter build number e.g. 42 or dev-42"
                    }
                    env.CLUSTER_NAME = params.ENVIRONMENT == 'prod' ?
                        env.PROD_CLUSTER : env.DEV_CLUSTER
                    env.ECR_REPO = params.ENVIRONMENT == 'prod' ?
                        'bankapp-prod' : 'bankapp-dev'
                    env.ROLLBACK_IMAGE = "${ECR_REGISTRY}/${ECR_REPO}:${params.IMAGE_TAG}"
                    echo "Rolling back ${params.ENVIRONMENT} to: ${env.ROLLBACK_IMAGE}"
                }
            }
        }

        stage('Approval') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input(
                        message: "⚠️ Rollback PRODUCTION to build ${params.IMAGE_TAG}?",
                        ok: 'Confirm Rollback',
                        submitter: 'admin,devops-lead'
                    )
                }
            }
        }

        stage('Rollback') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        aws eks update-kubeconfig \
                          --name ${CLUSTER_NAME} \
                          --region ${AWS_REGION}

                        echo "Rolling back to: ${ROLLBACK_IMAGE}"
                        kubectl set image deployment/bankapp \
                          bankapp=${ROLLBACK_IMAGE}

                        kubectl annotate deployment/bankapp \
                          kubernetes.io/change-cause="ROLLBACK to ${IMAGE_TAG} by Jenkins" \
                          --overwrite

                        kubectl rollout status deployment/bankapp --timeout=300s

                        echo "===== PODS AFTER ROLLBACK ====="
                        kubectl get pods

                        echo "===== CURRENT IMAGE ====="
                        kubectl get deployment bankapp \
                          -o=jsonpath='{.spec.template.spec.containers[0].image}'
                    '''
                }
            }
        }
    }

    post {
        success {
            emailext(
                subject: "✅ ROLLBACK SUCCESS — bankapp ${params.ENVIRONMENT} → build ${params.IMAGE_TAG}",
                body: "Rollback of bankapp ${params.ENVIRONMENT} to build ${params.IMAGE_TAG} completed successfully.",
                to: 'devops-team@company.com'
            )
        }
        failure {
            emailext(
                subject: "❌ ROLLBACK FAILED — bankapp ${params.ENVIRONMENT}",
                body: "Rollback failed! Check Jenkins: ${env.BUILD_URL}",
                to: 'devops-team@company.com'
            )
        }
        always {
            cleanWs()
        }
    }
}
