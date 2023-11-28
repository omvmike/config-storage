#!/bin/bash

# Configuration
gcs_base_path="gs://"

# Default GCP settings
bucket=${GCS_BUCKET:-""}
prefix=${PATH_PREFIX:-"configs"}

# Function to parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bucket) bucket="$2"; shift ;;
        --prefix) prefix="$2"; shift ;;
        *) break ;;
    esac
    shift
done

# Function to upload file to GCS with timestamp
set_env() {
    local local_path=$1
    local gcs_folder=$2
    local timestamp=$(date +%Y-%m-%d-%H%M%S)
    local gcs_path="${gcs_folder}${timestamp}"

    gsutil cp "$local_path" "$gcs_path" || { echo "Failed to upload file"; exit 1; }
    echo "File uploaded to $gcs_path"
}

# Function to download a specific or the latest file from GCS
get_env() {
    local env_name=$1
    local gcs_folder=$2
    local download_path=$3
    local version=$4
    local gcs_file

    if [ -z "$version" ]; then
        # Fetch the latest version if no specific version is provided
        gcs_file=$(gsutil ls "$gcs_folder" | sort | tail -n 1)
    else
        # Fetch the specified version
        gcs_file=$(gsutil ls "$gcs_folder" | grep "$version" | sort | tail -n 1)
    fi

    if [ -z "$gcs_file" ]; then
        echo "No file found in GCS"
        exit 1
    fi

    gsutil cp "$gcs_file" "$download_path" || { echo "Failed to download file"; exit 1; }
    echo "File version $gcs_file downloaded to $download_path"
}

# Function to list all versions of file in GCS
list_env_versions() {
    local param_name=$1
    local gcs_folder="$2"

    echo "Available versions for $param_name (newest first):"
    gsutil ls "$gcs_folder" | sort -r | awk -F '/' '{print $NF}'
}

# Function to delete a specific version of a file from GCS
delete_version() {
    local param_name=$1
    local gcs_folder=$2
    local version=$3

    local gcs_file="${gcs_folder}${version}"
    gsutil rm "$gcs_file" || { echo "Failed to delete version $version from GCS"; exit 1; }
    echo "Deleted version $version from GCS"
}

# Function to trim the oldest versions, keeping only a specified number of the most recent versions
trim_oldest() {
    local param_name=$1
    local gcs_folder=$2
    local keep_count=${3:-1}

    # Ensure keep_count is a valid number and greater than 0
    if ! [[ "$keep_count" =~ ^[0-9]+$ ]] || [ "$keep_count" -le 0 ]; then
        echo "Invalid keep count: $keep_count. It must be a positive integer."
        return 1
    fi

    echo "Trimming $param_name to $keep_count latest versions"

    # List all versions, sort them, and delete all but the 'keep_count' most recent versions
    local versions_to_delete=$(gsutil ls "$gcs_folder" | sort -r | tail -n +$((keep_count + 1)))

    for version in $versions_to_delete; do
        gsutil rm "$version" || { echo "Failed to delete version $version from GCS"; continue; }
        echo "Deleted version $version from GCS"
    done
    echo "Done"
}

about() {
    echo "Usage: $0 [set|get|list|delete|trim] [config-name] [bucket-name] [local-file-path] [version(optional)]"
    echo "Example: config-storage set .env /myapp-folder/.env"
    echo "Example: config-storage get .env /myapp-folder/.env"
    echo "Example: config-storage get .env /myapp-folder/.env 2020-01-01-123456"
    echo "Example: config-storage list .env"
    echo "Example: config-storage delete .env 2020-01-01-123456"
    echo "Example: config-storage trim .env 5"
    echo "---"
    echo "Simple GCS config manager"
    echo "The aim of this script is to simplify the management of environment specific config files in GCS"
    exit 1
}

# Main logic
if [ "$#" -lt 2 ]; then
    about
fi

if [ -n "$GCP_KEY_FILE" ]; then
    echo "Using GCP_KEY_FILE environment variable"
    echo "Setting GOOGLE_APPLICATION_CREDENTIALS to /tmp/key-file.json"
    echo "${GCP_KEY_FILE}" | base64 -d > /tmp/key-file.json
    gcloud auth activate-service-account --key-file /tmp/key-file.json --quiet ${GCLOUD_DEBUG_ARGS}
    PROJECT=$(jq -r '.project_id' /tmp/key-file.json)
    gcloud config set project $PROJECT --quiet ${GCLOUD_DEBUG_ARGS}
elif [ -n "$GCP_KEY_FILE_PATH" ]; then
    echo "Using GCP_KEY_FILE_PATH environment variable"
    echo "Setting GOOGLE_APPLICATION_CREDENTIALS to $GCP_KEY_FILE_PATH"
    gcloud auth activate-service-account --key-file $GCP_KEY_FILE_PATH --quiet ${GCLOUD_DEBUG_ARGS}
    PROJECT=$(jq -r '.project_id' $GCP_KEY_FILE_PATH)
    gcloud config set project $PROJECT --quiet ${GCLOUD_DEBUG_ARGS}
else
    echo "No GCP_KEY_FILE or GCP_KEY_FILE_PATH specified"
    exit 1
fi


echo "Using the following configuration:"
echo "- bucket: $bucket"
echo "- prefix: $prefix"

if [ -z "$bucket" ]; then
    echo "No bucket specified in GCS_BUCKET environment variable or --bucket argument"
    exit 1
fi

command=$1
name=$2
path=$3
version=$4

gcs_folder="${gcs_base_path}${bucket}/${prefix}/${name:+$name/}"

case $command in
    set)
        set_env "$path" "$gcs_folder"
        ;;
    get)
        get_env "$name" "$gcs_folder" "$path" "$version"
        ;;
    list)
        list_env_versions "$name" "$gcs_folder"
        ;;
    delete)
        delete_version "$name" "$gcs_folder" "$3"
        ;;
    trim)
        trim_oldest "$name" "$gcs_folder" "$3"
        ;;
    *)
        about
        ;;
esac
