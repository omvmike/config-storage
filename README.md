# config-storage
shell scripts and docker containers to manage config files within cloud buckets.

## Usage
Use `config-storage` to manage config files within cloud buckets.

You can use docker container or shell script.

Docker container is more preferable because it contains all necessary dependencies and can be used in CI/CD pipelines.

It will be beneficial to specify docker-compose.yml file in your project to run `config-storage` container with your project options.

```shell
# Set config file as .env key by getting it from /path/to/.env file
docker-compose run config-storage set .env /path/to/.env
# Get config file by .env key and save it as .env.dev
docker-compose run config-storage get .env .env.dev
# List all versions related to .env key
docker-compose run config-storage list .env
# Trim versions related to .env key to 10 last versions
docker-compose run config-storage trim .env 10
```



### Docker compose sample for AWS

### Docker compose sample for GCP

We use `gcloud` docker image to run `config-storage` container.
Yo should specify `GCP_KEY_FILE_PATH` environment variable to provide access to your GCP project.
It is container internal path to your GCP key file. So you can use volume option to mount your key file to this path.

Also container use `/tmp` folder as a working directory. 
So you can mount your project folder to container `/tmp` to use relative paths in your config files.

```yaml
version: '3.8'

services:
  config-storage:
    build: .
    image: gcp-config-storage
    entrypoint: config-storage
    environment:
      - GCS_BUCKET=my-config
      - PATH_PREFIX=config-storage/staging
      - GCP_KEY_FILE_PATH=/secrets/key.json
    volumes:
      - ./secrets:/secrets
      - .:/tmp
```
