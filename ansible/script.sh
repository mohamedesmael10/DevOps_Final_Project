#!/bin/bash

# Wait for EC2 instance creation
sleep 120

# Install Ansible if not already installed
if ! command -v ansible &> /dev/null
then
    echo "Ansible could not be found. Trying to install via apt..."
    
    # First attempt to install Ansible using apt
    sudo apt update
    sudo apt install -y software-properties-common python3-pip ansible

    # Check if Ansible was successfully installed via apt
    if ! command -v ansible &> /dev/null
    then
        echo "Ansible installation via apt failed. Trying to install via pip..."
        
        # If apt installation failed, attempt to install via pip
        pip3 install ansible
        
        # Final check to see if Ansible was installed successfully
        if ! command -v ansible &> /dev/null
        then
            echo "Failed to install Ansible via both apt and pip."
            exit 1  # Exit with an error code
        fi
    else
        echo "Ansible was successfully installed via apt."
    fi
else
    echo "Ansible is already installed."
fi

echo "Welcome to Esmael's private_instances. Ansible installation check complete." > /home/ubuntu/welcome.txt

# Apply the Ansible playbook
ansible-playbook configurations.yaml

