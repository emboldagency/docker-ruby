---
name: Ruby on Ubuntu
description: Ruby on Ubuntu with Postges, Mailpit, and Adminer
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby

![Semantic Versioning](https://embold.net/api/github/badge/semver.php?repo=docker-ruby) [![build-and-deploy.yml](https://embold.net/api/github/badge/workflow-status.php?repo=docker-ruby&workflow=build-and-deploy.yml)](https://github.com/emboldagency/docker-ruby/actions/workflows/build-and-deploy.yml)

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
export UBUNTU_VERSION=24.04

# Set the ruby version
export RUBY_VERSION=3.3.4

# Build the image
# Simple build (recommended for normal use):
docker buildx build -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} --build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load

# If you need full BuildKit output (useful for debugging) you have two options:
# 1) Add `--progress=plain` to stream the BuildKit output to your terminal:
docker buildx build --progress=plain -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} --build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load

# 2) Or set `DOCKER_BUILDKIT=1` and pipe to `tee` to capture a permanent log file:
DOCKER_BUILDKIT=1 docker buildx build --progress=plain -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} --build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load 2>&1 | tee build.log

# Push the image to the registry
docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}
```

## Coder Template Updates

The updated template will be published automatically when a new version tag is created on GitHub.

To manually run the job without pushing a release tag, or to skip the build step, see: [GitHub Actions Manual Run](#github-actions-manual-run)

### Manual Template Updates

Commit and push any changes to git, then do `coder templates push ruby` to push the template up to Coder.