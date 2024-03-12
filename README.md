---
name: Ruby on Ubuntu 22.04
description: Ruby on Ubuntu 22.04 with postgres
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby on Ubuntu 22.04

## Getting started

Clone the repo.

Commit and push any changes to git, then do `coder templates push ruby-ubuntu2204` to push the template up to Coder.

# Updating the image

The image builds automatically during startup if it doesn't already exist on the Coder server.

If you need to build/push manually:

```
# Set the base image version
UBUNTU_VERSION=22.04

# Build the image
docker build -t registry.embold.dev/ruby:rbenv-ubuntu$UBUNTU_VERSION ./build

# Push the image to the registry
docker push registry.embold.dev/ruby:rbenv-ubuntu$UBUNTU_VERSION
```
