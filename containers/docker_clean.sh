#!/bin/bash 


docker-compose down --remove-orphans --volumes --rmi all
docker system prune -a --volumes
#docker system prune -a --volumes -f
docker network prune

docker ps -a
docker images
docker network ls
docker volume ls
