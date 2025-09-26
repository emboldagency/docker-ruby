---
name: Ruby on Ubuntu
description: Ruby on Ubuntu with Postges, Mailpit, and Adminer
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby

![Semantic Versioning](https://embold.net/api/github/badge/semver.php?repo=docker-ruby) [![build-and-deploy.yml](https://embold.net/api/github/badge/workflow-status.php?repo=docker-ruby&workflow=build-and-deploy.yml)](https://github.com/emboldagency/docker-ruby/actions/workflows/build-and-deploy.yml)

# Build Process

Note: pushing a new image under an existing tag does not force the Coder server
to pull the updated image for already-pulled tags. To ensure new workspace
containers use the updated image you must either run `docker pull` on the
Coder host (or pull via Portainer) or create a new tag that Coder will fetch.

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

### Build Script

Use the included `build_image.sh` script to interactively build and optionally push the base image. The script provides sensible defaults so you can press Enter to continue.

```bash
./build_image.sh
```

### Docker commands

Export the variables:

```bash
# Set the base image version
export UBUNTU_VERSION=24.04

# Set the ruby version
export RUBY_VERSION=3.4.6

# Set the template version used by our CI and release tags
export TEMPLATE_VERSION=1.4.0
```

Build the image:
docker buildx build -t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
 --build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load

````

If you need full BuildKit output (useful for debugging) you have two options:
1) Add `--progress=plain` to stream the BuildKit output to your terminal:
```bash
docker buildx build --progress=plain \
	-t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
	--build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load
````

2. Or set `DOCKER_BUILDKIT=1` and pipe to `tee` to capture a permanent log file:

```bash
DOCKER_BUILDKIT=1 docker buildx build --progress=plain \
	-t emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION} \
	--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
	--build-arg RUBY_VERSION=${RUBY_VERSION} ./build --load 2>&1 | tee build.log
```

Push the image to the registry:

```bash
docker push emboldcreative/ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-release${TEMPLATE_VERSION}
```

## Companion Docker Images

This template uses custom Docker images for supporting services:

### Adminer (Database Management)

- **Repository**: [emboldagency/adminer-coder](https://github.com/emboldagency/adminer-coder)
- **Docker Hub**: `emboldcreative/adminer-coder:latest`
- **Features**: Coder-compatible, auto-login plugin, multi-database support

### Mailpit (Email Testing)

- **Repository**: [emboldagency/mailpit-coder](https://github.com/emboldagency/mailpit-coder)
- **Docker Hub**: `emboldcreative/mailpit-coder:latest`
- **Features**: Coder-compatible, web UI on port 18025, SMTP on port 1025

These images are pre-built and available on Docker Hub. The template pulls them automatically rather than building locally for faster workspace startup.

## Notes on build stages and slimming

This Dockerfile is now multi-stage: a `builder` stage contains build-only packages (compilers, -dev packages), and the final `runtime` stage only keeps runtime packages. This reduces final image size.

## Coder Template Updates

The updated template will be published automatically when a new version tag is created on GitHub.

To manually run the job without pushing a release tag, or to skip the build step, see: [GitHub Actions Manual Run](#github-actions-manual-run)

### Manual Template Updates

Commit and push any changes to git, then use the coder cli to push the template up to Coder.

```bash
coder templates push ruby --name ${TEMPLATE_VERSION}
```

Note: During testing, you can set `--activate=false` to push the template without marking it as the latest version, so new workspaces won't be prompted to update.
