#!/bin/bash

# Function to display the loading bar
show_loading_bar() {
  local duration=$1
  local interval=0.1
  local total_intervals=$(echo "$duration / $interval" | bc)
  local bar_length=50

  for ((i=0; i<=total_intervals; i++)); do
    local progress=$(echo "$i * $bar_length / $total_intervals" | bc)
    local percent=$(echo "$i * 100 / $total_intervals" | bc)
    local bar=$(printf "%-${bar_length}s" "#" | cut -c1-$progress)
    printf "\r[%-${bar_length}s] %d%%" "$bar" "$percent"
    sleep $interval
  done
  echo
}

# Run Terraform to apply the configuration
echo "Initializing Terraform..."
cd ./terraform
terraform init

echo "planning Terraform configuration..."
terraform plan

echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Get the external IP address of the Jenkins instance
EXTERNAL_IP=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address == "google_compute_instance.jenkins") | .values.network_interface[0].access_config[0].nat_ip')

if [ -z "$EXTERNAL_IP" ]; then
  echo "Failed to get the external IP address of the Jenkins instance."
  exit 1
fi

echo "Jenkins instance external IP: $EXTERNAL_IP"

# Retrieve the SSH key from Terraform output
terraform output -raw jenkins_ssh_private_key > ../jenkins_ssh_key.pem
chmod 600 ../jenkins_ssh_key.pem


# go back to the root directory
cd ..

echo "disable strict host key checking"
export ANSIBLE_HOST_KEY_CHECKING=False

# Update Ansible inventory with the new IP address
echo "[jenkins]
$EXTERNAL_IP ansible_ssh_user=debian ansible_ssh_private_key_file=jenkins_ssh_key.pem" > ./ansible/inventory.ini

# Wait for the Jenkins instance to be ready
echo "Waiting for Jenkins to be ready..."
show_loading_bar 10

# Run Ansible playbook
echo "Running Ansible playbook to configure Jenkins..."
ansible-playbook -i ./ansible/inventory.ini ./ansible/jenkins_setup.yml
