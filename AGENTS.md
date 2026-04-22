# Working on docker-ruby

Coder template (Terraform) + matching Ruby workspace image. The image builds `FROM ghcr.io/emboldagency/docker-base:ubuntu...`. Sibling to `docker-php` — most conventions mirror that repo.

## Layout

- `main.tf` — Coder template: declares workspace container, Postgres sidecar, composes modules from `emboldagency/coder-registry`
- `build/Dockerfile` — Ubuntu + Ruby image built on top of `docker-base`
- `build/Dockerfile.alpine` — Alpine variant
- `VERSION` — single source of truth for the template/image version suffix
- `build_image.sh` — local build helper; `TAG_SUFFIX` should be the contents of `VERSION` (no `v` prefix)
- `.github/workflows/` — builds a matrix of Ruby versions on `main` pushes (cache warm) and on tag pushes (versioned image + template push to Coder)

## Critical conventions

- **VERSION drives the image tag.** `main.tf` computes `ghcr.io/emboldagency/docker-ruby:${ruby_version}-ubuntu${ubuntu_version}-${template_version}`. Bumping VERSION without rebuilding and pushing the image breaks `data "docker_registry_image"` lookup at template-push time.
- The `v` prefix belongs only on git release tags, never on image tags.
- `data "docker_registry_image"` hits GHCR to resolve the image digest. For local-only iteration, temporarily swap it for a plain `docker_image` resource — but **don't commit that**.
- Module sources are pinned to `coder-registry` tags (e.g. `?ref=v2026.03.11.0`); bump them intentionally.
- `terraform.tfvars` is gitignored and holds `GHP_REGISTRY_PASS`.
- Workspace container attaches a single bridge network per workspace (`docker_network.workspace`). Ollama is reached via the public URL (`https://ollama.embold.dev`), not a shared docker network.
- The DB sidecar is Postgres (vs MySQL in docker-php); env vars `PGHOST`/`PGDATABASE`/`PGUSER`/`PGPASSWORD` and `DATABASE_URL` are wired into the workspace container.

## Release flow

1. Commit `main.tf` + `VERSION`.
2. Push to `main` → GHA warms the build cache.
3. `git tag vYYYY.MM.DD.N && git push --tags` → GHA builds the versioned image across the Ruby matrix and pushes the Coder template.

See `README.md` for manual build invocations.
