pipeline {
    agent any

    environment {
        APP_NAME = 'devops-demo'
        DOCKER_IMAGE = "${APP_NAME}:${BUILD_NUMBER}"
        ARTIFACT_DIR = 'artifacts'
        AWS_REGION = "${env.AWS_REGION ?: 'eu-north-1'}"
        K8S_NAMESPACE = 'dev'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout from GitHub') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
                echo "Branch: ${env.BRANCH_NAME ?: env.GIT_BRANCH}"
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    node --version
                    npm --version
                    npm ci
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh 'npm test'
            }
            post {
                always {
                    echo 'Test stage finished. Check console output above for pass/fail details.'
                }
            }
        }

        stage('Lint / Smoke Check') {
            steps {
                sh 'npm run lint'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${DOCKER_IMAGE} .
                    docker tag ${DOCKER_IMAGE} ${APP_NAME}:latest
                """
            }
        }

        stage('Validate Container') {
            steps {
                sh '''
                    docker rm -f jenkins-validate 2>/dev/null || true
                    docker run -d --name jenkins-validate \
                      -e NODE_ENV=test \
                      -e APP_VERSION=${BUILD_NUMBER} \
                      ${DOCKER_IMAGE}

                    for i in 1 2 3 4 5 6 7 8 9 10; do
                      if docker exec jenkins-validate wget -qO- http://127.0.0.1:3000/health; then
                        echo "Health check passed on attempt ${i}"
                        break
                      fi
                      if [ "${i}" -eq 10 ]; then
                        echo "Health check failed after 10 attempts"
                        docker logs jenkins-validate
                        exit 1
                      fi
                      sleep 2
                    done

                    docker exec jenkins-validate wget -qO- http://127.0.0.1:3000/api/info
                    docker exec jenkins-validate wget -qO- http://127.0.0.1:3000/metrics | head -20

                    docker stop jenkins-validate
                    docker rm jenkins-validate
                '''
            }
        }

        stage('Archive Artifacts') {
            steps {
                sh """
                    mkdir -p ${ARTIFACT_DIR}
                    docker save ${DOCKER_IMAGE} -o ${ARTIFACT_DIR}/${APP_NAME}-${BUILD_NUMBER}.tar
                """
                archiveArtifacts artifacts: "${ARTIFACT_DIR}/**/*", fingerprint: true
            }
        }

        stage('Deploy to AWS Dev (Kubernetes)') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    if (!env.K8S_SSH_HOST?.trim()) {
                        echo 'K8S_SSH_HOST not set — skipping AWS deploy.'
                        echo 'Setup guide: docs/AWS-AUTO-DEPLOY.md'
                        return
                    }
                }
                sh '''
                    SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes"
                    if [ -n "${SSH_KEY_PATH:-}" ] && [ -f "${SSH_KEY_PATH}" ]; then
                      SSH_OPTS="${SSH_OPTS} -i ${SSH_KEY_PATH}"
                    fi

                    docker save ${DOCKER_IMAGE} | ssh ${SSH_OPTS} ${K8S_SSH_HOST} 'sudo k3s ctr images import -'
                    ssh ${SSH_OPTS} ${K8S_SSH_HOST} "sudo k3s ctr images tag ${DOCKER_IMAGE} ${APP_NAME}:latest"

                    export KUBECONFIG=${KUBECONFIG:-/root/.kube/dev-config}
                    chmod +x scripts/deploy-k8s.sh
                    IMAGE=${APP_NAME}:latest ./scripts/deploy-k8s.sh

                    echo "Deployed ${DOCKER_IMAGE} to AWS dev environment"
                '''
            }
        }

        stage('Post-Deploy Validation') {
            when {
                expression { return env.ALB_DNS?.trim() }
            }
            steps {
                sh '''
                    chmod +x scripts/test-connectivity.sh scripts/validate-deployment.sh
                    ./scripts/test-connectivity.sh ${ALB_DNS}
                    ./scripts/validate-deployment.sh http://${ALB_DNS}
                '''
            }
        }
    }

    post {
        success {
            echo """
            Pipeline SUCCESS
            Build: ${BUILD_NUMBER}
            Image: ${DOCKER_IMAGE}
            Jenkins shows each stage above — use Blue Ocean or Stage View for visual flow.
            """
        }
        failure {
            echo 'Pipeline FAILED. Check stage logs, then run scripts/test-connectivity.sh against your host.'
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
