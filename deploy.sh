#!/bin/bash

# Configuration
REMOTE_IP=${1:-"10.36.88.165"}  # Default IP if not provided
REMOTE_USER="root"
REMOTE_PASS="password"
IMAGE_NAME="ai-agent"
DEPLOYMENT_FILE="di-agent-deployment.yaml"
TAR_FILE="${IMAGE_NAME}.tar"

# Function to check if sshpass is installed
check_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        echo "Installing sshpass..."
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
}

# Function to setup passwordless SSH
setup_ssh() {
    echo "Setting up passwordless SSH..."
    
    # Generate SSH key if it doesn't exist
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    fi
    
    # Copy SSH key to remote server
    sshpass -p "${REMOTE_PASS}" ssh-copy-id -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_IP}
    
    if [ $? -eq 0 ]; then
        echo "Passwordless SSH setup completed successfully"
    else
        echo "Failed to setup passwordless SSH"
        exit 1
    fi
}

# Main deployment function
deploy() {
    echo "Starting deployment to ${REMOTE_IP}..."

    # Build Docker image
    echo "Building Docker image..."
    docker build -t ${IMAGE_NAME} .
    if [ $? -ne 0 ]; then
        echo "Docker build failed"
        exit 1
    fi

    # Save Docker image to tar
    echo "Saving Docker image to ${TAR_FILE}..."
    docker save ${IMAGE_NAME} > ${TAR_FILE}

    # Copy files to remote server
    echo "Copying files to remote server..."
    scp ${TAR_FILE} ${REMOTE_USER}@${REMOTE_IP}:/root/
    scp ${DEPLOYMENT_FILE} ${REMOTE_USER}@${REMOTE_IP}:/root/

    # Load image and deploy on remote server
    echo "Loading image and deploying on remote server..."
    ssh ${REMOTE_USER}@${REMOTE_IP} << EOF
        # Load Docker image
        docker load < /root/${TAR_FILE}
        
        # Apply Kubernetes deployment
        kubectl apply -f /root/${DEPLOYMENT_FILE}
        
        # Clean up tar file
        rm /root/${TAR_FILE}
EOF

    # Clean up local tar file
    rm ${TAR_FILE}

    echo "Deployment completed!"

    # Show deployment status
    echo "Checking deployment status..."
    ssh ${REMOTE_USER}@${REMOTE_IP} "kubectl get pods | grep ${IMAGE_NAME}"
}

# Main execution
check_sshpass
setup_ssh
deploy