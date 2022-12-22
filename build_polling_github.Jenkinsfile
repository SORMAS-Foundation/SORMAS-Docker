node {
        
    stage('checkout') {
        git branch: '${BRANCH}', url: 'https://github.com/hzi-braunschweig/SORMAS-Docker.git'
    }

    stage('set variables') {
    	sh "sed -i '/^GEO_TEMPLATE/d ' ./.env"
    }

    stage('Build') {
        sh """
        source ./.env
        sudo docker system prune -f
        sudo docker build --pull --no-cache -t sormas-application:latest sormas/
        sudo docker build  --no-cache -t sormas-postgres:latest postgres/
        sudo docker build --pull --no-cache -t sormas-apache2:latest apache2/
        sudo docker build --pull --no-cache -t sormas-pg-dump:latest pg_dump/
        sudo docker build --pull --no-cache -t sormas-keycloak:latest keycloak/
        sudo docker build --pull --no-cache -t sormas-keycloak-postgres:latest keycloak-postgres/
        sudo docker build --pull --no-cache -t sormas-pg-debug:latest pg_debug/
        """
    }
}