#!/bin/bash

# Configuration
s3_base_path="s3://"

# Default AWS profile
# If AWS_PROFILE environment variable is set, use --profile flag with its value, otherwise use empty string
aws_profile=${AWS_PROFILE:+"--profile $AWS_PROFILE"}
bucket=${AWS_BUCKET:-""}
prefix=${PATH_PREFIX:-"configs"}
# Function to parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --profile) aws_profile="$1 $2"; shift ;;
        --bucket) bucket="$2"; shift ;;
        --prefix) prefix="$2"; shift ;;
        *) break ;;
    esac
    shift
done

# Function to upload file to S3 with timestamp
set_env() {
    local local_path=$1
    local s3_folder=$2
    local timestamp=$(date +%Y-%m-%d-%H%M%S)
    local s3_path="${s3_folder}${timestamp}"

    aws s3 cp $aws_profile "$local_path" "$s3_path" || { echo "Failed to upload .env file"; exit 1; }
    echo ".env file uploaded to $s3_path"
}

# Function to download a specific or the latest file from S3
get_env() {
    local env_name=$1
    local s3_folder=$2
    local download_path=$3
    local version=$4
    local s3_file

    if [ -z "$version" ]; then
        # Fetch the latest version if no specific version is provided
        s3_file=$(aws s3 ls $aws_profile "$s3_folder" | sort | tail -n 1 | awk '{print $4}')
    else
        # Fetch the specified version
        s3_file=$(aws s3 ls $aws_profile "$s3_folder" | grep "$version" | sort | tail -n 1 | awk '{print $4}')
    fi

    if [ -z "$s3_file" ]; then
        echo "No .env file found in S3"
        exit 1
    fi

    aws s3 cp $aws_profile "${s3_folder}${s3_file}" "$download_path" || { echo "Failed to download .env file"; exit 1; }
    echo ".env file version $s3_file downloaded to $download_path"
}

# Function to list all versions of file in S3
list_env_versions() {
    local param_name=$1
    local s3_folder="$2"

    echo "Available versions for $param_name (newest first):"
    aws s3 ls $aws_profile "$s3_folder" | sort -r | awk '{print $4}'
}

# Function to delete a specific version of a file from S3
delete_version() {
    local param_name=$1
    local s3_folder=$2
    local version=$3

    local s3_file="${s3_folder}${version}"
    aws s3 rm $aws_profile "$s3_file" || { echo "Failed to delete version $version from S3"; exit 1; }
    echo "Deleted version $version from S3"
}

# Function to trim the oldest versions, keeping only a specified number of the most recent versions
trim_oldest() {
   local param_name=$1
    local s3_folder=$2
    local keep_count=${3:-1}

    # Ensure keep_count is a valid number and greater than 0
    if ! [[ "$keep_count" =~ ^[0-9]+$ ]] || [ "$keep_count" -le 0 ]; then
        echo "Invalid keep count: $keep_count. It must be a positive integer."
        return 1
    fi

    echo "Trimming $param_name to $keep_count latest versions"

    # List all versions, sort them, and delete all but the 'keep_count' most recent versions
    local versions_to_delete=$(aws s3 ls $aws_profile "$s3_folder" | sort -r | tail -n +$((keep_count + 1)) | awk '{print $4}')

#    echo "Number of versions to delete: $(echo "$versions_to_delete" | wc -l)"

    for version in $versions_to_delete; do
        aws s3 rm $aws_profile "${s3_folder}${version}" || { echo "Failed to delete version $version from S3"; continue; }
        echo "Deleted version $version from S3"
    done
    echo "Done"
}

about() {
    echo "Usage: $0 [set|get|list|delete|trim] [config-name] [bucket-name] [local-file-path] [version(optional)]"
    echo "Example: $0 set .env /myapp-folder/.env"
    echo "Example: $0 get .env /myapp-folder/.env"
    echo "Example: $0 get .env /myapp-folder/.env 2020-01-01-123456"
    echo "Example: $0 list .env"
    echo "Example: $0 delete .env 2020-01-01-123456"
    echo "Example: $0 trim .env 5"
    echo "---"
    echo "Simple S3 config manager"
    echo "The aim of this script is to simplify the management of environment specific config files in S3"
    exit 1
}

# Main logic
if [ "$#" -lt 2 ]; then
    about
fi

if [ -n "$AWS_OIDC_ROLE_ARN" ]; then
    echo "Assuming role: $AWS_OIDC_ROLE_ARN"
    role_session_name="SomeSessionName" # You can customize this session name

    # Assume role and get temporary credentials
    creds=$(aws sts assume-role --role-arn "$AWS_OIDC_ROLE_ARN" --role-session-name "$role_session_name" --query 'Credentials' --output json)

    # Set temporary credentials for subsequent AWS CLI commands
    AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r '.AccessKeyId')
    export AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r '.SecretAccessKey')
    export AWS_SECRET_ACCESS_KEY
    AWS_SESSION_TOKEN=$(echo "$creds" | jq -r '.SessionToken')
    export AWS_SESSION_TOKEN
    echo "OIDC credentials set"
fi


echo "Using the following configuration:"
echo "- AWS credentials: ${aws_profile:-AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY used}" ${AWS_SESSION_TOKEN:+"-- OIDC token used"}
echo "- bucket: $bucket"
echo "- prefix: $prefix"

if [ -z "$bucket" ]; then
    echo "No bucket specified in AWS_BUCKET environment variable or --bucket argument"
    exit 1
fi

command=$1
name=$2
path=$3
version=$4

s3_folder="${s3_base_path}${bucket}/${prefix}/${name:+$name/}"

case $command in
    set)
        set_env "$path" "$s3_folder"
        ;;
    get)
        get_env "$name" "$s3_folder" "$path" "$version"
        ;;
    list)
        list_env_versions "$name" "$s3_folder"
        ;;
    delete)
        delete_version "$name" "$s3_folder" "$3"
        ;;
    trim)
        trim_oldest "$name" "$s3_folder" "$3"
        ;;
    *)
        about
        exit 1
        ;;
esac