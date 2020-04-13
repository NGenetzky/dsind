#!/bin/bash

set -o errexit

main() {
  check_args "$@"

  local image=$1
  local tag=$2

  local token=$(get_token $image)
  local manifest=$(get_manifest $image $tag $token)
  local digest=$(echo ${manifest} | jq -r '.config.digest')

  get_image_configuration $image $token $digest
}

get_image_configuration() {
  local image=$1
  local token=$2
  local digest=$3

  echo "Retrieving Image Configuration.
    IMAGE:  $image
    DIGEST: $digest
  " >&2

  curl \
    --silent \
    --location \
    --header "Authorization: Bearer $token" \
    "https://registry-1.docker.io/v2/$image/blobs/$digest" \
    | jq -r '.container_config'
}

get_token() {
  local image=$1

  echo "Retrieving Docker Hub token.
    IMAGE: $image
  " >&2

  curl \
    --silent \
    "https://auth.docker.io/token?scope=repository:$image:pull&service=registry.docker.io" \
    | jq -r '.token'
}

get_manifest() {
  local image=$1
  # NOTE: reference can be tag or digest
  local reference=$2
  local token=$3

  echo "Retrieving image digest.
    IMAGE:  $image
    REFERENCE:    $reference
  " >&2

  curl \
    --silent \
    --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    --header "Authorization: Bearer $token" \
    "https://registry-1.docker.io/v2/$image/manifests/$reference" \
    | jq -r ''
}

check_args() {
  if (($# != 2)); then
    echo "Error:
    Two arguments must be provided - $# provided.
  
    Usage:
      ./get-image-config.sh <image> <tag>
      
Aborting."
    exit 1
  fi
}

main "$@"
