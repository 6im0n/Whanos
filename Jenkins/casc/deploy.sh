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
	echo "Invalid project: more than one language criterias matched (${LANGUAGE[@]})."
	exit 1
fi

echo "${LANGUAGE[@]} found."

if test -f "./Dockerfile"; then
    echo "Using base image"
    docker build . -t whanos-project-$1
else
    echo "Using standalone image"
    docker build . -t whanos-project-$1 -f /images/$LANGUAGE/Dockerfile.standalone
fi
docker tag whanos-project-$1 localhost:5000/whanos-project-$1
docker push localhost:5000/whanos-project-$1
docker pull localhost:5000/whanos-project-$1
docker rmi whanos-project-$1

if test -f "./whanos.yml"; then
    echo "Deploying on kubernetes"
    FILE_CONTENT=`cat ./whanos.yml | base64 -w 0`
    curl -H "Content-Type: application/json" -X POST -d "{\"image\":\"localhost:5000/whanos-project-$1\",\"config\":\"$FILE_CONTENT\",\"name\":\"$1\"}" http://localhost:3030/deployments
fi
mkdir -p /usr/share/jenkins_hash
echo `git log -n 1  | grep commit | awk '{ print $2 }'` > /usr/share/jenkins_hash/JENKINS_HASH_$1