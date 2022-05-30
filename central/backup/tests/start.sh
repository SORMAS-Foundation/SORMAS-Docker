#!/bin/bash

docker-compose down && sudo rm -fr volumes/ && docker-compose up --build --remove-orphans
