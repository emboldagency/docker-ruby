---
name: Ruby on Ubuntu
description: Ruby on Ubuntu with Postges
tags: [local, docker]
icon: /icon/docker.png
---

# Ruby

[![Calendar Semantic Versioning](https://img.shields.io/github/v/release/emboldagency/docker-ruby?label=calendar%20semver)](https://github.com/emboldagency/docker-ruby/releases)

# Build Process

Note: pushing a new image under an existing tag does not force the Coder server
to pull the updated image for already-pulled tags. To ensure new workspace
containers use the updated image you must either run `docker pull` on the
Coder host (or pull via Portainer) or create a new tag that Coder will fetch.

## Automated Builds

GitHub Actions is configured to:

- automatically build and push the base images to GHCR
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

### Using the Build Script (Recommended)

For local development and testing, use the included helper script. It prompts for the Ubuntu & Ruby versions and an optional tag suffix, then runs the build with the correct arguments.

```bash
./build_image.sh
```

### Using Docker CLI

Set the base image version and Ruby version

```bash
export UBUNTU_VERSION=24.04
export RUBY_VERSION=3.4.6
```

Set the template version used by our CI and release tags.

```bash
export TEMPLATE_VERSION=2026.03.12.0
```

Build the image

```bash
docker buildx build \
  --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
  --build-arg RUBY_VERSION=${RUBY_VERSION}
  -t ghcr.io/emboldagency/docker-ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-${TEMPLATE_VERSION} \
  ./build --load
```

If you are pushing to GHCR, authenticate first.

- The username is the owner of the PAT.
- The password is in Bitwarden on the `GitHub (Alert/Staging)` entry as `GHCR Token (Write)`.

```bash
export GHCR_USER="emboldagency"
export GHCR_TOKEN="<your-ghcr-pat-with-packages-write>"
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
```

Push the image to the registry

```bash
docker push ghcr.io/emboldagency/docker-ruby:${RUBY_VERSION}-ubuntu${UBUNTU_VERSION}-${TEMPLATE_VERSION}
```

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

Note: During testing, you can set `--activate=false` to push the template without marking it as the latest version, so new workspaces won't be prompted to update. Coder does not allow deleting a template version, so once the template name is pushed, you'll need to use a new name for subsequent updates.
