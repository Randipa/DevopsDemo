pipeline {
    agent any

    environment {
        APP_NAME = 'devops-demo'
        DOCKER_IMAGE = "${APP_NAME}:${BUILD_NUMBER}"
        ARTIFACT_DIR = 'artifacts'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    triggers {
        // Poll GitHub every 2 minutes — auto-build after push (no public URL needed)
        pollSCM('H/2 * * * *')
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
    }

    post {
        success {
            echo """
            Pipeline SUCCESS
            Build: ${BUILD_NUMBER}
            Image: ${DOCKER_IMAGE}
            AWS deploy: push to main → GitHub Actions (Development + Stage auto)
            Jenkins: auto trigger via pollSCM (~2 min after push)
            """
        }
        failure {
            echo 'Pipeline FAILED — check stage logs in Blue Ocean or Console Output.'
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
