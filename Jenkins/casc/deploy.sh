#!/bin/bash

language=()

if [[ -f Makefile ]]; then
	LANGUAGE+=("c")
fi
if [[ -f app/pom.xml ]]; then
	LANGUAGE+=("java")
fi
if [[ -f package.json ]]; then
	LANGUAGE+=("javascript")
fi
if [[ -f requirements.txt ]]; then
	LANGUAGE+=("python")
fi
if [[ $(find app -type f) == app/main.bf ]]; then
	LANGUAGE+=("befunge")
fi

if [[ ${#LANGUAGE[@]} == 0 ]]; then
	echo "Invalid project: no language matched. Supported languages: c, java, javascript, python, befunge."
	exit 1
fi
if [[ ${#LANGUAGE[@]} != 1 ]]; then
	echo "Invalid project: more than one language criteria matched (${LANGUAGE[@]})."
	exit 1
fi

echo "${LANGUAGE[@]} found."

source /home/gcloud/google-cloud-sdk/path.bash.inc

source /var/jenkins_home/.env

image_name=$REGISTRY_HOST/whanos-${LANGUAGE[0]}/$1

echo "Building image $image_name"

if [[ -f Dockerfile ]]; then
    echo "Dockerfile found in the application"
    docker build . -t $image_name - < /var/jenkins_home/images/${LANGUAGE[0]}/Dockerfile.base
else
    echo "Dockerfile not found in the application"
    docker build . -t $image_name -f /var/jenkins_home/images/${LANGUAGE[0]}/Dockerfile.standalone
fi

docker push $image_name

if test -f "./whanos.yml"; then
    echo "Whanos.yml file found in the application"
    echo "Trying to deploy"
    cat whanos.yml
    ## generate the kubernetes file for the deployment
    /var/jenkins_home/kube_scripts/generate_deployement.sh $image_name $1
    cat deployment.yaml
    kubectl apply -f deployment.yaml
    kubectl describe services $1-service
    kubectl get services $1-service
    kubectl get services $1-service -o jsonpath='http://{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}'
    echo ""
fi
