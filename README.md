---
name: Ruby on Ubuntu
description: Ruby on Ubuntu with Postgres
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby

[![Build and Deploy](https://github.com/emboldagency/docker-ruby/actions/workflows/build-and-deploy.yml/badge.svg)](https://github.com/emboldagency/docker-ruby/actions/workflows/build-and-deploy.yml) <!--
-->![Semantic Versioning](https://img.shields.io/badge/semver-2.0.0-green?logo=semver)

# Build Process

## Automated Builds

GitHub Actions is configured to:
- automatically build and push the base images to DockerHub 
- push the updated templates to Coder when a new version tag is created on GitHub

The jobs are defined in [build-and-deploy.yml](.github/workflows/build-and-deploy.yml)

### GitHub Actions Manual Run

You can also start the GitHub Actions workflow manually using the [GitHub CLI](https://cli.github.com/).

```bash
# Optionally set the reference branch, commit SHA, or tag for the workflow run (e.g., main, v2.0.1, f74efaac558c7f0dcda915d23ef5387942341cb2)
export REFERENCE="main"

# Optionally set the skip jobs field to a comma separated list of jobs to skip.
# See [build-and-deploy.yml](.github/workflows/build-and-deploy.yml)
export SKIP_JOBS="build-and-push-docker"

gh workflow run build-and-deploy.yml --ref $REFERENCE --field skip-jobs=$SKIP_JOBS
```

## Manual Builds

```bash
# Set the base image version
export UBUNTU_VERSION=22.04

# Set the ruby version
export RUBY_VERSION=3.3.4

# Build the image
docker build -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION} --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} --build-arg RUBY_VERSION=${RUBY_VERSION} ./build

# Push the image to the registry
docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}
```

## Coder Template Updates

The updated template will be published automatically when a new version tag is created on GitHub.

To manually run the job without pushing a release tag, or to skip the build step, see: [GitHub Actions Manual Run](#github-actions-manual-run)

### Manual Template Updates

Commit and push any changes to git, then do `coder templates push ruby` to push the template up to Coder.