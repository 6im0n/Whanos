#!/bin/bash

IGNORE_TERRAFORM=false

# Ensure $OUTPUT_FILE is deleted on script exit or interruption
cleanup() {
  echo "Cleaning up temporary files..."
  rm -f "$OUTPUT_FILE"
  rm -f jenkins_ssh_key.pem
}
trap cleanup EXIT

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
  echo "  --ignore-tera     Skip Terraform deployment steps"
  echo
  echo "This script automates the setup of a Jenkins instance using Terraform and Ansible."
}

# Check for options
VERBOSE=false
for arg in "$@"; do
  case $arg in
    -h|--help)
      display_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    --ignore-terraform)
      IGNORE_TERRAFORM=true
      shift
      ;;
  esac
done

# Function to run commands with or without verbose output
run_command() {
  local command="$1"
  if [ "$VERBOSE" = true ]; then
    eval "$command"
  else
    eval "$command > /dev/null 2>&1"
  fi
}

cd ./terraform

# Terraform steps (conditionally skipped)
if [ "$IGNORE_TERRAFORM" = false ]; then
  # Step 1: Initialize Terraform
  printf "🔧 Initializing Terraform...\n"
  run_command "terraform init"

  # Step 2: Plan Terraform Configuration
  printf "📝 Planning Terraform configuration...\n"
  run_command "terraform plan"

  # Step 3: Apply Terraform Configuration
  printf "🚀 Applying Terraform configuration...\n"
  run_command "terraform apply -auto-approve"

  # Step 4: Wait for Jenkins to be ready
  printf "⏳ Waiting for Jenkins to be ready...\n"
  show_loading_bar 7

else
  echo "Skipping Terraform deployment as --ignore-tera option was set."
  EXTERNAL_IP="<set-manually-or-configure>"
fi

# Step 4: Retrieve Jenkins Instance External IP Address
printf "📡 Retrieving Jenkins instance external IP...\n"
EXTERNAL_IP=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address == "google_compute_instance.jenkins") | .values.network_interface[0].access_config[0].nat_ip')

if [ -z "$EXTERNAL_IP" ]; then
  echo "❌ Failed to get the external IP address of the Jenkins instance."
  exit 1
fi

printf "🔑 Jenkins instance external IP: $EXTERNAL_IP\n"

# Step 5: Retrieve SSH Key from Terraform Output
printf "🔙 Retrieving SSH key from Terraform output...\n"
terraform output -raw jenkins_ssh_private_key > ../jenkins_ssh_key.pem
chmod 600 ../jenkins_ssh_key.pem

# Step 6: retrieve the artifact registry URL
printf "🔙 Retrieving artifact registry URL from Terraform output...\n"
echo | terraform output -raw docker_registry_url
echo ""


# Step 6: Go Back to the Root Directory
printf "🔐 Returning to root directory...\n"
cd ..

# Step 7: Disable Strict Host Key Checking
printf "⏳ Disabling strict host key checking...\n"
export ANSIBLE_HOST_KEY_CHECKING=False

# Step 8: Update Ansible Inventory with the New IP Address
printf "🛠️ Updating Ansible inventory...\n"
echo "[jenkins]
$EXTERNAL_IP ansible_ssh_user=debian ansible_ssh_private_key_file=jenkins_ssh_key.pem" > ./ansible/inventory.ini


# Step 10: Run Ansible Playbook to Configure Jenkins
printf "🛠️ Running Ansible playbook to configure Jenkins...\n"
set -a
source .env
set +a
TEMPLATE_FILE=./casc/jenkins-casc.yml
OUTPUT_FILE=./casc/jenkins-casc-resolved.yml
envsubst < $TEMPLATE_FILE > $OUTPUT_FILE

if [ "$VERBOSE" = true ]; then
  eval "ansible-playbook -i ./ansible/inventory.ini ./ansible/jenkins_setup.yml"
else
  eval "ansible-playbook -i ./ansible/inventory.ini ./ansible/jenkins_setup.yml > /dev/null 2>&1"
fi
rm -f $OUTPUT_FILE

# Step 12: Display Jenkins URL
printf "📡 Jenkins URL: http://$EXTERNAL_IP:8080\n"

# Step 13: Delete the SSH key
rm -f jenkins_ssh_key.pem

printf "✅ Jenkins setup completed successfully!\n"
