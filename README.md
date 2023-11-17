---
name: Ruby 3.0.2 on Ubuntu 22.04
description: Ruby 3.0.2 on Ubuntu 22.04 with postgres
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby 3.0.2 on Ubuntu 22.04

## Getting started

Clone the repo.

Commit and push any changes to git, then do `coder templates push ruby302-ubuntu2204` to push the template up to Coder.

# Updating the image

Autobuilds are turned on in Dockerhub whenever the branch has a new commit or docker-base gets updated.

If you need to build/push manually:

Run `docker build -t registry.embold.app/ruby:3.0.2-ubuntu22.04 ./build` to build the image

Run `docker push registry.embold.app/ruby:3.0.2-ubuntu22.04`to push the image to Docker Hub
