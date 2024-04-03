---
name: Ruby
description: Ruby on Ubuntu with Postgres
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby

## Getting started

Clone the repo.

Commit and push any changes to git, then do `coder templates push ruby` to push the template up to Coder.

# Updating the image

```
# Set the base image version
export UBUNTU_VERSION=22.04

# Set the ruby version
export RUBY_VERSION=3.0.2

# Build the image
docker build -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION} --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} --build-arg RUBY_VERSION=${RUBY_VERSION} ./build

# Push the image to the registry
docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}
```
