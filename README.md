# config-storage
shell scripts and docker containers to manage config files within cloud buckets.

The aim is to simplify config files management for CI/CD pipelines by providing docker containers
and shell scripts to update and get config files from cloud buckets(AWS S3, GCP Bucket).

You should just specify your cloud bucket name and path prefix to your config files.
Prefix could be useful to separate config files for different environments.

In advance every time you update your config file, `config-storage` will create a new version of the file
by just adding new object with timestamp suffix to the bucket. So you can easily rollback to previous version of your config file.

I intentionally don't use bucket versioning because might want to use any existing bucket with or without versioning. 
So I decided to implement simple versioning mechanism based on object names.
It looks suitable for config files because they don't change very often.

So, for example, if want to save your config files in `my-bucket` bucket with `config-storage/test` prefix,
and you want to save your `.env` file, the file will be saved as `config-storage/test/.env/2023-11-28-121822` object in your bucket.
Whe `2023-11-28` is date and `121822` is time `HHMMSS` when the file was saved.

## Usage
Use `config-storage` to manage config files within cloud buckets.

You can use docker container or shell script.

Docker container is more preferable because it contains all necessary dependencies and can be used in CI/CD pipelines.

It will be beneficial to specify docker-compose.yml file in your project to run `config-storage` container with your project options.

See [Docker compose sample for AWS](#docker-compose-sample-for-aws) and [Docker compose sample for GCP](#docker-compose-sample-for-gcp) sections for more details.


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

We use alpine image with `awscli` installed to run `config-storage` container.

You should specify `AWS_PROFILE` environment variable to provide access to your AWS account.

> In this case you should mount your `~/.aws` folder to container `/root/.aws` path to provide access to your AWS credentials.

Otherwise, you can use `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

Container use `/tmp` folder as a working directory.
So you can mount your project folder to container `/tmp` to use relative paths in your config files.

```yaml
version: '3.8'

services:
  config-storage:
    image: ghcr.io/omvmike/config-storage:aws
    environment:
      - AWS_PROFILE=omvmike
      - AWS_BUCKET=my-bucket
      #      - AWS_ACCESS_KEY_ID=your_access_key
      #      - AWS_SECRET_ACCESS_KEY=your_secret_key
      - PATH_PREFIX=config-storage/test
    volumes:
      - ./:/tmp
      - ~/.aws:/root/.aws
```

### Docker compose sample for GCP

We use `gcloud` docker image to run `config-storage` container.
You should specify `GCP_KEY_FILE_PATH` environment variable to provide access to your GCP project.
It is container internal path to your GCP key file. So you can use volume option to mount your key file to this path.

Also container use `/tmp` folder as a working directory. 
So you can mount your project folder to container `/tmp` to use relative paths in your config files.

```yaml
version: '3.8'

services:
  config-storage:
    image: ghcr.io/omvmike/config-storage:gcp
    environment:
      - GCS_BUCKET=my-config
      - PATH_PREFIX=config-storage/staging
      - GCP_KEY_FILE_PATH=/secrets/key.json
    volumes:
      - ./secrets:/secrets
      - .:/tmp
```

### Bitbucket pipelines samples

Sample of bitbucket-pipelines.yml file for GCP


```yaml
dev:
  - step:
      name: Obtain environment variables
      image: ghcr.io/omvmike/config-storage:gcp
      script:
        - export GCP_KEY_FILE=$KEY_FILE_BASE64
        - export GCS_BUCKET=my-bucket
        - export PATH_PREFIX=config-storage/dev
        - config-storage get .env api.env
      artifacts:
        - api.env
```
it will bethe same for AWS,
just change image name to `ghcr.io/omvmike/config-storage:aws`
and provide `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables instead of `GCP_KEY_FILE`

```yaml
dev:
  - step:
      name: Obtain environment variables
      image: ghcr.io/omvmike/config-storage:aws
      script:
        - export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
        - export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
        - export AWS_BUCKET=my-bucket
        - export PATH_PREFIX=config-storage/dev
        - config-storage get .env api.env
      artifacts:
        - api.env
```

For AWS you can use `oidc` option to get temporary credentials from AWS STS service.


```yaml
  dev:
    - step: 
        name: Obtain environment variables
        image: ghcr.io/omvmike/config-storage:aws
        oidc: true
        script:
          - export AWS_OIDC_ROLE_ARN=arn:aws:iam::123456789012:role/MyRoleName
          - export PATH_PREFIX=config-storage/dev
          - export AWS_BUCKET=my-bucket
          - config-storage get .env api.env
        artifacts:
          - api.env
```