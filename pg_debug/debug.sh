#!/usr/bin/bash
eval $(head ../.env)
docker run \
  --network sormas-docker_default \
  -it registry.netzlink.com/hzibraunschweig/pg_debug:${SORMAS_VERSION} \
  bash
