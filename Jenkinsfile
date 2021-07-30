node {
    
    def SORMAS_VERSION=''
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }
    
    stage('set variables') {
        echo 'Setting variables'
        sh """
        sed -i 's,SORMAS_URL=.*$,SORMAS_URL=http://10.160.41.100/,' ./.env
		sed -i 's,SORMAS_DOCKER_VERSION=.*\$,SORMAS_DOCKER_VERSION=${SORMAS_DOCKER_VERSION},' ./.env
		sed -i "/^GEO_TEMPLATE/d " ./.env
        """        
        SORMAS_VERSION= sh (
        	script: "curl -s https://raw.githubusercontent.com/hzi-braunschweig/SORMAS-Project/development/sormas-base/pom.xml | grep SNAPSHOT | sed s/\<version\>// | sed s/\<\\/version\>// | sed 's/[[:space:]]//g'", 
        	resturnStdout: true
        ).trim()
        echo "${SORMAS_VERSION}"
    }

    stage('Build SORMAS') {
                     
    }
    
    stage('Build LBDS') {
		echo 'Building....'
        withCredentials([ usernamePassword(credentialsId: 'crowdcodeNexus', usernameVariable: 'CROWDCODE_NEXUS_USER', passwordVariable: 'CROWDCODE_NEXUS_PASSWORD' )]) {
        	sh """
        	cd lbds
        	sudo buildah bud --pull-always --no-cache --build-arg LDBS_JAR_FILE_VERSION=${LDBS_JAR_FILE_VERSION} --build-arg CROWDCODE_NEXUS_USER=${CROWDCODE_NEXUS_USER} --build-arg CROWDCODE_NEXUS_PASSWORD="${CROWDCODE_NEXUS_PASSWORD}" -t hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION} .
        	"""
        }
    }
 
    
    stage('Deploy') {
        echo 'Deploying....'
        withCredentials([ usernamePassword(credentialsId: 'registry.netzlink.com', usernameVariable: 'MY_SECRET_USER_NLI', passwordVariable: 'MY_SECRET_USER_PASSWORD_NLI' )]) {
        	sh """
        	echo "${MY_SECRET_USER_NLI}"
        	echo "'${MY_SECRET_USER_NLI}'"

            sudo buildah login -u '$MY_SECRET_USER_NLI' -p '$MY_SECRET_USER_PASSWORD_NLI' registry.netzlink.com
            sudo buildah push -f v2s2 hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION} registry.netzlink.com/hzibraunschweig/lbds:${LDBS_JAR_FILE_VERSION}
            echo 'Finished'
            """                                                                                                                 
        }
    }
}