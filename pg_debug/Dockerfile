FROM debian:bullseye

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      python3 \
      python3-dev \
      python3-pip \
      pgcluu \
      pgstat \
      pgtop \
      python3-psycopg2 && \
    python3 -m pip install \
      pg_activity

CMD [ "sleep", "infinity" ]
