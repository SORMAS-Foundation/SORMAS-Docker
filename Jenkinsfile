node {
    
    def SORMAS_VERSION=''
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables'
        sh """
        sed -i 's,SORMAS_URL=.*\$,SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/,' ./.env
		sed -i "/^GEO_TEMPLATE/d " ./.env
		cat ./.env
        """        
        SORMAS_VERSION= sh (
        	script: 'echo $(grep SORMAS_VERSION= .env) | cut -c16-21', 
        	returnStdout: true
        ).trim()
        echo "${SORMAS_VERSION}"
    }

    stage('Build SORMAS') {
    	echo 'Building SORMAS'
    	sh """
    	source ./.env
    	sudo buildah bud --build-arg SORMAS_URL="https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/" --build-arg SORMAS_VERSION=${SORMAS_VERSION} --pull-always --no-cache -t sormas-application:${SORMAS_DOCKER_VERSION} sormas/
		sudo buildah bud  --build-arg SORMAS_URL="https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/" --build-arg SORMAS_VERSION=${SORMAS_VERSION} --no-cache -t sormas-postgres:${SORMAS_DOCKER_VERSION} postgres/
		sudo buildah bud --build-arg SORMAS_URL="https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/" --build-arg SORMAS_VERSION=${SORMAS_VERSION} --pull-always --no-cache -t sormas-apache2:${SORMAS_DOCKER_VERSION} apache2/
		sudo buildah bud --build-arg SORMAS_URL="https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/" --build-arg SORMAS_VERSION=${SORMAS_VERSION} --pull-always --no-cache -t sormas-pg-dump:${SORMAS_DOCKER_VERSION} pg_dump/
    	"""
    }
    
    
    stage('DEPLOY SORMAS to local registry') {
    echo 'Deploying....'
        withCredentials([ usernamePassword(credentialsId: 'registry.netzlink.com', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
        	sudo buildah login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' registry.netzlink.com
        	sudo buildah push -f v2s2 sormas-application:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-postgres:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-apache2:${SORMAS_DOCKER_VERSION}  registry.netzlink.com/hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-pg-dump:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
        	"""
        }    
	}
	stage('DEPLOY SORMAS to dockerhub') {
    echo 'Deploying....'
        withCredentials([ usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'MY_SECRET_USER', passwordVariable: 'MY_SECRET_USER_PASSWORD' )]) {
        	sh """
        	
        	sudo buildah login -u '$MY_SECRET_USER' -p '$MY_SECRET_USER_PASSWORD' docker.io
        	
        	sudo buildah push -f v2s2 sormas-application:${SORMAS_DOCKER_VERSION} hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-postgres:${SORMAS_DOCKER_VERSION} hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-apache2:${SORMAS_DOCKER_VERSION}  hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo buildah push -f v2s2 sormas-pg-dump:${SORMAS_DOCKER_VERSION} hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
        	"""
        }    
	}

}