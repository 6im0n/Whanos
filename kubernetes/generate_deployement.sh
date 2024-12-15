#!/bin/bash

# Ensure required arguments are passed
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <image> <project_name>"
  exit 1
fi

image="$1"
project_name="$2"

# Define paths
deployment_template="/var/jenkins_home/kube_scripts/templates/deployment.yaml"
service_template="/var/jenkins_home/kube_scripts/templates/service.yaml"
whanos_config="whanos.yml"
output_file="deployment.yaml"

# Check required files
if [[ ! -f $deployment_template || ! -f $service_template || ! -f $whanos_config ]]; then
  echo "Required files are missing: $deployment_template, $service_template, or $whanos_config"
  exit 1
fi

# Load YAML data
deployment=$(cat "$deployment_template")
service=$(cat "$service_template")
whanos=$(yq eval "." "$whanos_config")

# Extract values from whanos.yml
replicas=$(yq eval '.deployment.replicas // 1' <<< "$whanos")
ports=($(yq eval '.deployment.ports[]' <<< "$whanos" 2>/dev/null))

# Update deployment placeholders
deployment=$(echo "$deployment" | sed "s/whanos-name/$project_name/g")
deployment=$(echo "$deployment" | sed "s/whanos-image/$image/g")
deployment=$(echo "$deployment" | yq eval ".spec.replicas = $replicas" -)

# Handle ports in deployment
if [[ ${#ports[@]} -gt 0 ]]; then
  ports_yaml=""
  for port in "${ports[@]}"; do
    ports_yaml+="- containerPort: $port"
  done
  deployment=$(echo "$deployment" | sed "/containerPort: port/c\            ${ports_yaml}")
else
  deployment=$(echo "$deployment" | sed "/containerPort: port/d")
fi

# Update service placeholders
service=$(echo "$service" | sed "s/whanos-name/$project_name/g")

# Handle ports in service
if [[ ${#ports[@]} -gt 0 ]]; then
  ports_yaml=""
  for port in "${ports[@]}"; do
    ports_yaml+="- port: $port"
  done
  service=$(echo "$service" | sed "/port: port/c\    ${ports_yaml}")
else
  service=$(echo "$service" | sed "/port: port/d")
fi

# Combine deployment and service YAML
final_yaml=$(echo -e "$deployment\n---\n$service")

# Write to output file
echo "$final_yaml" > "$output_file"

echo "Generated deployment.yaml successfully."
