#build
docker build -f docker/Dockerfile.cpu -t ml-env:latest .

#start
docker run -it --env-file .env ml-env:latest