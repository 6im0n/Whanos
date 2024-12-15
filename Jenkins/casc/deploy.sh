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

image_name=$DOCKER_REGISTRY/whanos/whanos-$1-${LANGUAGE[0]}

if [[ -f Dockerfile ]]; then
	docker build . -t $image_name
else
  echo "Using standalone image"
	docker build . \
		-f /images/${LANGUAGE[0]}/Dockerfile.standalone \
		-t $image_name
fi

if test -f "./whanos.yml"; then
    echo "Whanos.yml file found in the application"
    echo "Trying to deploy"
    ## generate the kububernetes file for the deployment
    /var/jenkins_home/kubernetes/generate_deployement.sh localhost:5000/whanos-project-$1 $1
    ./kubernetes/make_deployment.sh localhost:5000/whanos-project-$1 $1
    curl -H "Content-Type: application/json" -X POST -d "{\"image\":\"localhost:5000/whanos-project-$1\",\"config\":\"$FILE_CONTENT\",\"name\":\"$1\"}" http://localhost:3030/deployments
fi

mkdir -p /usr/share/jenkins_hash
echo `git log -n 1  | grep commit | awk '{ print $2 }'` > /usr/share/jenkins_hash/JENKINS_HASH_$1