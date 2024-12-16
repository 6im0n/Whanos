folder('Projects') {
    displayName('Projects')
    description('Folder containing jobs for the Whanos projects')
}

folder('Whanos base images') {
    displayName('Whanos Base Images')
    description('Folder containing jobs to build the Whanos base images')
}

def languages = ['c', 'java', 'javascript', 'python', 'befunge']

freeStyleJob("google-cloud-artifacts-auth") {
  parameters{
    stringParam("GOOGLE_PROJECT_ID", null, "Your Google Cloud project ID ex: whanos-123456")
    fileParam("gcloud-service-account-key.json", "Service account key file ex: gcloud-service-account-key.json")
    stringParam("GCLOUD_KUBERNETE_CLUSTER_NAME", null, "Name of the cluster ex: whanos-cluster")
    stringParam("GCLOUD_KUBERNETE_CLUSTER_LOCATION", null, "Location of the cluster ex: europe-west9")
    stringParam("GOOGLE_ARTIFACT_REGISTRY_ZONE", "europe-west9-docker", "Google artifact registry zone ex : europe-west9-docker")
  }
  steps {
    shell("cat gcloud-service-account-key.json | docker login -u _json_key --password-stdin https://\$GOOGLE_ARTIFACT_REGISTRY_ZONE.pkg.dev")
    shell("/home/gcloud/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=gcloud-service-account-key.json")
    shell("/home/gcloud/google-cloud-sdk/bin/gcloud config set project \$GOOGLE_PROJECT_ID")
    shell("/home/gcloud/google-cloud-sdk/bin/gcloud container clusters get-credentials \$GCLOUD_KUBERNETE_CLUSTER_NAME --zone \$GCLOUD_KUBERNETE_CLUSTER_LOCATION")
  }
}

languages.each { language ->
    job("Whanos base images/whanos-${language}") {
        description("Build the base image for Whanos ${language}")
        steps {
            shell("""
                echo "Building Whanos base image for ${language}"
                docker build -t whanos-${language} -f /var/jenkins_home/images/${language}/Dockerfile.base /var/jenkins_home/images/${language}
            """)
        }
    }
}

job('Whanos base images/Build all base images') {
    description('Triggers all Whanos base image build jobs')
    steps {
        shell("echo 'Triggering all Whanos base image build jobs'")
    }
    publishers {
        downstream(languages.collect { "Whanos base images/whanos-${it}" }, 'SUCCESS')
    }
}

freeStyleJob('link-project') {
    description('Link a project')
    parameters {
        stringParam('REPO_URL', '', 'Git repository URL (e.g. "https://github.com/Chocolatine/choco.git")')
        stringParam('NAME', '', 'Name of the project to name the job')
    }
    steps {
        dsl {
            text('''
                freeStyleJob("Projects/${NAME}") {
                    scm {
                        git {
                            remote {
                                name("origin")
                                url("${REPO_URL}")
                            }
                        }
                    }
                    triggers {
                        scm('* * * * *')
                    }
                    wrappers {
                        preBuildCleanup()
                    }
                    steps {
                        shell("/var/jenkins_home/deploy.sh ${NAME}")
                    }
                }
            ''')
        }
    }
}
