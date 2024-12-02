folder('Projects') {
    displayName('Projects')
    description('Folder containing jobs for the Whanos projects')
}

folder('Whanos base images') {
    displayName('Whanos Base Images')
    description('Folder containing jobs to build the Whanos base images')
}

def languages = [c, java, javascript, python, befunge]

languages.each { language ->
    job("Whanos base images/whanos-${language}") {
        description("Build the base image for Whanos ${language}")
        steps {
            shell("""
                echo "Building Whanos base image for ${language}"
                docker build -t whanos-${language} -f Dockerfile.${language} .
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

job('link-project') {
    description('Link a project')
    parameters {
        stringParam('PROJECT_NAME', '', 'Name of the project')
        stringParam('GITHUB_NAME', '', 'GitHub repository owner/repo_name (e.g.: "Epitech/whanos")')
        /*how to handle private repositories?*/
    }
    steps {}
}
