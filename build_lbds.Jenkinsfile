node {
    
    
    
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    

        
    stage('Build LBDS') {
		echo 'Building....'
        withCredentials([ usernamePassword(credentialsId: 'crowdcodeNexus', usernameVariable: 'CROWDCODE_NEXUS_USER', passwordVariable: 'CROWDCODE_NEXUS_PASSWORD' )]) {
        	sh """
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