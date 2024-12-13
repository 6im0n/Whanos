#!/bin/bash

# Ensure required arguments are passed
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <image> <project_name>"
  exit 1
fi

image="$1"
project_name="$2"

# Define paths
deployment_template="./templates/deployment.yaml"
service_template="./templates/service.yaml"
whanos_config="./templates/whanos.yaml"
output_file="deployment.yaml"

# Check required files
if [[ ! -f $deployment_template || ! -f $service_template || ! -f $whanos_config ]]; then
  echo "Required files are missing: $deployment_template, $service_template, or $whanos_config"
  exit 1
fi

# Load YAML data
deployment=$(yq eval "." "$deployment_template")
service=$(yq eval "." "$service_template")
whanos=$(yq eval "." "$whanos_config")

# Initialize variables
replicas=$(yq eval '.replicas // 1' <<< "$whanos")
limits_cpu=$(yq eval '.limitscpu // ""' <<< "$whanos")
limits_memory=$(yq eval '.limitsmemory // ""' <<< "$whanos")
requests_cpu=$(yq eval '.requestscpu // ""' <<< "$whanos")
requests_memory=$(yq eval '.requestsmemory // ""' <<< "$whanos")
ports=($(yq eval '.ports // [] | .[]' <<< "$whanos"))

# Update deployment with image and replicas
deployment=$(yq eval ".spec.template.spec.containers[0].image = \"$image\"" <<< "$deployment")
deployment=$(yq eval ".spec.replicas = $replicas" <<< "$deployment")

# Add resource limits and requests
resources="{}"
if [[ -n $limits_cpu || -n $limits_memory ]]; then
  resources=$(yq eval ".limits.cpu = \"$limits_cpu\"" <<< "$resources")
  resources=$(yq eval ".limits.memory = \"$limits_memory\"" <<< "$resources")
fi
if [[ -n $requests_cpu || -n $requests_memory ]]; then
  resources=$(yq eval ".requests.cpu = \"$requests_cpu\"" <<< "$resources")
  resources=$(yq eval ".requests.memory = \"$requests_memory\"" <<< "$resources")
fi
if [[ $resources != "{}" ]]; then
  deployment=$(yq eval ".spec.template.spec.containers[0].resources = $resources" <<< "$deployment")
fi

# Update ports in deployment and service
if [[ ${#ports[@]} -gt 0 ]]; then
  ports_yaml="[]"
  for port in "${ports[@]}"; do
    ports_yaml=$(yq eval ". += [{containerPort: $port}]" <<< "$ports_yaml")
    service=$(yq eval ".spec.ports += [{port: $port, targetPort: $port}]" <<< "$service")
  done
  deployment=$(yq eval ".spec.template.spec.containers[0].ports = $ports_yaml" <<< "$deployment")
else
  deployment=$(yq eval "del(.spec.template.spec.containers[0].ports)" <<< "$deployment")
fi

# Combine deployment and service YAML
final_yaml=$(echo -e "$deployment\n---\n$service")

# Replace placeholders
final_yaml=$(echo "$final_yaml" | sed "s/whanos-name/$project_name/g")

# Write to output file
echo "$final_yaml" > "$output_file"

echo "Generated $output_file successfully."
