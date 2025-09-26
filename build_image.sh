#!/usr/bin/env bash

# Prompt for missing environment variables
prompt_var() {
  local var="$1"
  local prompt="$2"
  if [ -z "${!var}" ]; then
    read -rp "$prompt: " val
    export "$var"="$val"
  fi
}

prompt_var UBUNTU_VERSION "Enter Ubuntu version (e.g. 24.04)"
prompt_var RUBY_VERSION "Enter Ruby version (e.g. 3.4.6)"
prompt_var TEMPLATE_VERSION "Enter template version (e.g. 1.4.0)"

red="\033[0;31m"
cyan="\033[0;36m"
reset="\033[0m"

echo_error() {
    echo -e "${red}Error: $1${reset}"
    exit 1
}

echo_highlight() {
    echo -e "${cyan}$1${reset}"
}

# Show the values to be used
echo_highlight "The following values will be used to build the image:"
echo "  UBUNTU_VERSION:    $UBUNTU_VERSION"
echo "  RUBY_VERSION:      $RUBY_VERSION"
echo "  TEMPLATE_VERSION:  $TEMPLATE_VERSION"
echo

read -rp "Proceed with these values? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo_error "Aborted. To avoid prompts, export the required environment variables before running this script:"
  echo "  export UBUNTU_VERSION=24.04"
  echo "  export RUBY_VERSION=3.4.6"
  echo "  export TEMPLATE_VERSION=1.4.0"
  exit 1
fi

# Build the image
DOCKER_BUILDKIT=1 docker build -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION} \
  --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
  --build-arg RUBY_VERSION=${RUBY_VERSION} \
  ./build

# Check if the build was successful
if [ $? -ne 0 ]; then
  echo_error "Build failed. Please check the output for errors."
  exit 1
fi

echo "To push the image, run:"
echo_highlight "  docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION}"

read -rp "Do you want to push the image now? [y/N]: " push_answer
if [[ "$push_answer" =~ ^[Yy]$ ]]; then
  docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION}
fi