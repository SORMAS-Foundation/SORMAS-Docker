node {
    
    def SORMAS_VERSION=''
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables'
 	sed -i 's,SORMAS_URL=.*$,SORMAS_URL=http://10.160.41.100/,' ./.env
	sed -i 's,SORMAS_DOCKER_VERSION=.*$,SORMAS_DOCKER_VERSION=DEVOPS,' ./.env
	sed -i "/^GEO_TEMPLATE/d " ./.env
        SORMAS_VERSION=$(curl -s https://raw.githubusercontent.com/hzi-braunschweig/SORMAS-Project/development/sormas-base/pom.xml | grep SNAPSHOT | sed s/\<version\>// | sed s/\<\\/version\>// | sed 's/[[:space:]]//g')
        echo "${SORMAS_VERSION}"
    }

    stage('Build SORMAS') {
        echo 'Building PGDUMP'
        cat ./.env
    }

    stage('DEPLOY SORMAS') {
        echo 'Deploying pgdump'
    }

}
