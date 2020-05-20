FROM hzibraunschweig/sormas-rscript:3.5

ARG SORMAS_POSTGRES_PASSWORD=password
ARG SORMAS_POSTGRES_USER=sormas_user
ARG SORMAS_SERVER_URL=sormas-docker-test.com
ARG DB_HOST=postgres
ARG DOMAIN_NAME=sormas
ARG DB_NAME=sormas
ARG DB_NAME_AUDIT=sormas_audit
ARG SMTP_HOST=localhost
ARG SMTP_USE_STARTTLS=false
ARG SMTP_PORT=25
ARG SMTP_LOCALHOST=
ARG SMTP_USER=
ARG SMTP_PASSWORD=

ARG EMAIL_SENDER_ADDRESS=noreply@localhost
ARG EMAIL_SENDER_NAME=Sormas
ARG EMAIL_ERROR_TO=sormas-admin@localhost

ARG JVM_MAX=4096m
ARG SORMAS_URL=https://github.com/hzi-braunschweig/SORMAS-Project/releases/download/
EXPOSE 6080
ARG SORMAS_VERSION=1.40.1

ENV MAIL_FROM=root@localhost
ENV DEBIAN_FRONTEND=noninteractive
EXPOSE 6048

ENV ASENV_PATH="/opt/payara5/glassfish/config/asenv.conf"
RUN useradd payara
COPY setup-server.sh /setup-server.sh
COPY logback.xml /logback.xml
RUN /setup-server.sh
RUN cat /opt/domains/sormas/config/logback.xml
COPY start-server.sh /start-server.sh
RUN chmod +x /start-server.sh
RUN apt-get install -y telnet ssmtp
CMD ["/start-server.sh"]
