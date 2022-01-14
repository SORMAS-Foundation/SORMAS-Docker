node {
    
    def SORMAS_VERSION=''
    def SORMAS_VERSION_NIGHTLY=''
    
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables'
        SORMAS_VERSION_NIGHTLY= sh (
        	script: 'curl -s https://raw.githubusercontent.com/hzi-braunschweig/SORMAS-Project/development/sormas-base/pom.xml | grep SNAPSHOT | sed s/\\<version\\>// | sed s/\\<\\\\/version\\>// | sed \'s/[[:space:]]//g\'', 
        	returnStdout: true
        ).trim()
        if (params.BUILD_NIGHTLY != null && params.BUILD_NIGHTLY) {
            echo 'Build NIGHTLY'
			SORMAS_VERSION = SORMAS_VERSION_NIGHTLY
			sh """
			sed -i 's,SORMAS_URL=.*\$,SORMAS_URL=http://10.160.41.100/,' ./.env
			"""
        }
        else {
            echo 'Build Version from .env'
            SORMAS_VERSION = sh (
            	script: "source ./.env &> /dev/null && echo \$SORMAS_VERSION",
            	returnStdout: true
            ).trim()
        }
        sh """
		sed -i 's,SORMAS_DOCKER_VERSION=.#*\$,SORMAS_DOCKER_VERSION=${SORMAS_DOCKER_VERSION},' ./.env
		sed -i "/^GEO_TEMPLATE/d " ./.env
		cat ./.env
        """        
        
        
        echo "${SORMAS_VERSION}"
    }

    stage('Build SORMAS') {
    	echo 'Building SORMAS'
    	sh """
    	source ./.env
    	sudo docker build --build-arg SORMAS_URL=\$SORMAS_URL --build-arg SORMAS_VERSION=\$SORMAS_VERSION --pull --no-cache -t sormas-application:${SORMAS_DOCKER_VERSION} sormas/ 
    	sudo docker build  --build-arg SORMAS_URL=\$SORMAS_URL --build-arg SORMAS_VERSION=\$SORMAS_VERSION --pull --no-cache -t sormas-postgres:${SORMAS_DOCKER_VERSION} postgres/
		sudo docker build --build-arg SORMAS_URL=\$SORMAS_URL --build-arg SORMAS_VERSION=\$SORMAS_VERSION --pull --no-cache -t sormas-apache2:${SORMAS_DOCKER_VERSION} apache2/
		sudo docker build --build-arg SORMAS_URL=\$SORMAS_URL --build-arg SORMAS_VERSION=\$SORMAS_VERSION --pull --no-cache -t sormas-pg-dump:${SORMAS_DOCKER_VERSION} pg_dump/
    	"""
    }
    
    
    stage('DEPLOY SORMAS') {
    echo 'Deploying locally....'
        withCredentials([ usernamePassword(credentialsId: 'registry.netzlink.com', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
        	sudo docker login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' registry.netzlink.com
            sudo docker tag sormas-application:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
            sudo docker push registry.netzlink.com/hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-postgres:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo docker push registry.netzlink.com/hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-apache2:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo docker push registry.netzlink.com/hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-pg-dump:${SORMAS_DOCKER_VERSION} registry.netzlink.com/hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
			sudo docker push registry.netzlink.com/hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
        	"""
        }
          
    echo 'Deploying to docker.io....'
        withCredentials([ usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
        	sudo docker login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' docker.io
            sudo docker tag sormas-application:${SORMAS_DOCKER_VERSION} docker.io/hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
            sudo docker push docker.io/hzibraunschweig/sormas-application:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-postgres:${SORMAS_DOCKER_VERSION} docker.io/hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo docker push docker.io/hzibraunschweig/sormas-postgres:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-apache2:${SORMAS_DOCKER_VERSION} docker.io/hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo docker push docker.io/hzibraunschweig/sormas-apache2:${SORMAS_DOCKER_VERSION}
			sudo docker tag sormas-pg-dump:${SORMAS_DOCKER_VERSION} docker.io/hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
			sudo docker push docker.io/hzibraunschweig/sormas-pg-dump:${SORMAS_DOCKER_VERSION}
        	"""
        }  
	}

    
    stage('Build LBDS') {
		echo 'Building....'
        withCredentials([ usernamePassword(credentialsId: 'crowdcodeNexus', usernameVariable: 'CROWDCODE_NEXUS_USER', passwordVariable: 'CROWDCODE_NEXUS_PASSWORD' )]) {
        	sh """
        	source ./.env
        	cd lbds
        	sudo docker build --pull --no-cache --build-arg LDBS_JAR_FILE_VERSION=${LDBS_JAR_FILE_VERSION} --build-arg CROWDCODE_NEXUS_USER=${CROWDCODE_NEXUS_USER} --build-arg CROWDCODE_NEXUS_PASSWORD="${CROWDCODE_NEXUS_PASSWORD}" -t hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION} .
        	"""
        }
    }
 
    
    stage('Deploy LBDS') {
        echo 'Deploying....'
        withCredentials([ usernamePassword(credentialsId: 'registry.netzlink.com', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
            sudo docker login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' registry.netzlink.com
            sudo docker tag hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION} registry.netzlink.com/hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION}
            sudo docker push  registry.netzlink.com/hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION}
            sudo docker tag hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION} registry.netzlink.com/hzibraunschweig/lbds:$${SORMAS_DOCKER_VERSION}
            sudo docker push registry.netzlink.com/hzibraunschweig/lbds:$${SORMAS_DOCKER_VERSION}
            echo 'Finished'
            """                                                                                                                 
        }
    }
}