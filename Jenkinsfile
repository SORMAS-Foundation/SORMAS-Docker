node {
    
    def SORMAS_VERSION=''
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables for pgdump'
    }

    stage('Build SORMAS') {
        echo 'Building pgdump'
    }
    
    
    stage('DEPLOY SORMAS') {
        echo 'Deploying pgdump'
    }
    
}
