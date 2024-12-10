#!/bin/bash

# Function to display the loading bar with emoji animation
show_loading_bar() {
  local duration=$1
  local interval=0.1
  local total_intervals=$(echo "$duration / $interval" | bc)
  local bar_length=50

  for ((i=0; i<=total_intervals; i++)); do
    local progress=$(echo "$i * $bar_length / $total_intervals" | bc)
    local percent=$(echo "$i * 100 / $total_intervals" | bc)
    local bar=$(printf "%-${bar_length}s" "" | tr ' ' '#')
    bar=$(echo "$bar" | head -c $progress)
    local emoji=("🌱" "🌿" "🌳" "🌲" "🍀")
    local emoji_index=$((i % ${#emoji[@]}))
    printf "\r[%-${bar_length}s] %d%% %s" "$bar" "$percent" "${emoji[$emoji_index]}"
    sleep $interval
  done
  echo
}

# Function to display help message
display_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -h, --help        Show this help message and exit"
  echo "  -v, --verbose     Show detailed output of each command"
  echo
  echo "This script automates the setup of a Jenkins instance using Terraform and Ansible."
  echo "It initializes Terraform, plans and applies the configuration, retrieves the Jenkins instance's external IP,"
  echo "disables strict host key checking, updates the Ansible inventory, waits for the Jenkins instance to be ready,"
  echo "and finally runs the Ansible playbook to configure Jenkins."
}

# Check for help option
VERBOSE=false
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  display_help
  exit 0
elif [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
  VERBOSE=true
fi

# Function to run commands with or without verbose output
run_command() {
  local command="$1"
  if [ "$VERBOSE" = true ]; then
    eval "$command"
  else
    eval "$command > /dev/null 2>&1"
  fi
}

# Run Terraform to apply the configuration
step_emoji=("🔧" "📝" "🚀" "📡" "🔑" "🔙" "🔐" "⏳" "🛠️")

# Step 1: Initialize Terraform
printf "${step_emoji[0]} Initializing Terraform...\n"
cd ./terraform
run_command "terraform init"

# Step 2: Plan Terraform Configuration
printf "${step_emoji[1]} Planning Terraform configuration...\n"
run_command "terraform plan"

# Step 3: Apply Terraform Configuration
printf "${step_emoji[2]} Applying Terraform configuration...\n"
run_command "terraform apply -auto-approve"

# Step 4: Retrieve Jenkins Instance External IP Address
printf "${step_emoji[3]} Retrieving Jenkins instance external IP...\n"
EXTERNAL_IP=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address == "google_compute_instance.jenkins") | .values.network_interface[0].access_config[0].nat_ip')

if [ -z "$EXTERNAL_IP" ]; then
  echo "❌ Failed to get the external IP address of the Jenkins instance."
  exit 1
fi

printf "${step_emoji[4]} Jenkins instance external IP: $EXTERNAL_IP\n"

# Step 5: Retrieve SSH Key from Terraform Output
printf "${step_emoji[5]} Retrieving SSH key from Terraform output...\n"
terraform output -raw jenkins_ssh_private_key > ../jenkins_ssh_key.pem
chmod 600 ../jenkins_ssh_key.pem

# Step 6: Go Back to the Root Directory
printf "${step_emoji[6]} Returning to root directory...\n"
cd ..

# Step 7: Disable Strict Host Key Checking
printf "${step_emoji[7]} Disabling strict host key checking...\n"
export ANSIBLE_HOST_KEY_CHECKING=False

# Step 8: Update Ansible Inventory with the New IP Address
printf "${step_emoji[8]} Updating Ansible inventory...\n"
echo "[jenkins]
$EXTERNAL_IP ansible_ssh_user=debian ansible_ssh_private_key_file=jenkins_ssh_key.pem" > ./ansible/inventory.ini

# Step 9: Wait for the Jenkins Instance to Be Ready
printf "⏳ Waiting for Jenkins to be ready...\n"
show_loading_bar 7

# Step 10: Run Ansible Playbook to Configure Jenkins
printf "🛠️ Running Ansible playbook to configure Jenkins...\n"
set -a
source .env
set +a
TEMPLATE_FILE=./casc/jenkins-casc.yml
OUTPUT_FILE=./casc/jenkins-casc-resolved.yml
envsubst < $TEMPLATE_FILE > $OUTPUT_FILE

Jenkins
if [ "$VERBOSE" = true ]; then
  eval "ansible-playbook -i ./ansible/inventory.ini ./ansible/jenkins_setup.yml"
else
  printf "🔒 Get the initial Jenkins admin password:\n"
  output=$(ansible-playbook -i ./ansible/inventory.ini ./ansible/jenkins_setup.yml | grep 'Initial Jenkins admin password is')
  echo -e "\033[0;32m${output}\033[0m"
fi
rm -f $OUTPUT_FILE

# Step 12: Display Jenkins URL
printf "📡 Jenkins URL: http://$EXTERNAL_IP:8080\n"

# step 13: Delete the SSH key
rm -f jenkins_ssh_key.pem

printf "✅ Jenkins setup completed successfully!\n"
