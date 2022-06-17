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
			sed -i 's,SORMAS_VERSION=.*\$,SORMAS_VERSION=${SORMAS_VERSION},' ./.env
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

        
    stage('Build LBDS') {
		echo 'Building....'
        withCredentials([ usernamePassword(credentialsId: 'crowdcodeNexus', usernameVariable: 'CROWDCODE_NEXUS_USER', passwordVariable: 'CROWDCODE_NEXUS_PASSWORD' )]) {
        	sh """
        	source ./.env
        	cd lbds
        	sudo docker build --pull --no-cache --build-arg LBDS_JAR_FILE_VERSION=${LBDS_JAR_FILE_VERSION} --build-arg CROWDCODE_NEXUS_USER=${CROWDCODE_NEXUS_USER} --build-arg CROWDCODE_NEXUS_PASSWORD="${CROWDCODE_NEXUS_PASSWORD}" -t hzibraunschweig/lbds:${LBDS_JAR_FILE_VERSION} .
        	"""
        }
    }
 
    
    stage('Deploy LBDS to registry') {
        echo 'Deploying....'
        withCredentials([ usernamePassword(credentialsId: 'registry.netzlink.com', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
            sudo docker login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' registry.netzlink.com
            sudo docker tag hzibraunschweig/lbds:${LBDS_JAR_FILE_VERSION} registry.netzlink.com/hzibraunschweig/lbds:${LBDS_JAR_FILE_VERSION}
            sudo docker push  registry.netzlink.com/hzibraunschweig/lbds:${LBDS_JAR_FILE_VERSION}
            sudo docker tag hzibraunschweig/lbds:${LBDS_JAR_FILE_VERSION} registry.netzlink.com/hzibraunschweig/lbds:${SORMAS_DOCKER_VERSION}
            sudo docker push registry.netzlink.com/hzibraunschweig/lbds:${SORMAS_DOCKER_VERSION}
            echo 'Finished'
            """                                                                                                                 
        }
    }
}