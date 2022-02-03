FROM debian:bullseye

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      pgstat \
      pgtop \
      pg-activity

CMD [ "sleep", "infinity" ]
