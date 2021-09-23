node {
    
    def SORMAS_VERSION=''
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables'
        SORMAS_VERSION=pgdump-devops
        echo "${SORMAS_VERSION}"
    }

    stage('Build SORMAS') {
        echo 'Building SORMAS'
    }
    
    
    stage('DEPLOY SORMAS') {
        echo 'Deploying....'
    }
    
}
