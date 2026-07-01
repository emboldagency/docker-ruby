terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.13"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

# ------------------------------------------------------------------------------
# Providers
# ------------------------------------------------------------------------------

provider "coder" {}

provider "docker" {
  registry_auth {
    address  = "ghcr.io"
    username = "emboldagency"
    password = var.GHP_REGISTRY_PASS
  }
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

variable "GHP_REGISTRY_PASS" {
  sensitive = true
}

# Token for the shared browserless service (infrastructure-docs/stacks/browserless).
# Must match BROWSERLESS_TOKEN in that stack. Supply via the gitignored terraform.tfvars.
variable "playwright_token" {
  type      = string
  sensitive = true
}

# ------------------------------------------------------------------------------
# Coder Parameters
# ------------------------------------------------------------------------------

data "coder_parameter" "pulsar_app_name" {
  name        = "Pulsar App Name"
  description = "What is the Pulsar app name? If this is blank, the workspace name will be used."
  icon        = "https://api.embold.net/icons/title.svg"
  type        = "string"
  default     = ""
  mutable     = true
  order       = 1
}

data "coder_parameter" "pulsar_magic_template" {
  name        = "Pulsar Magic Template?"
  description = "Should we use the Pulsar magic template to dynamically build the Pulsar configuration?"
  type        = "bool"
  icon        = "https://api.embold.net/icons/fas-magic-wand.svg"
  default     = false
  mutable     = true
  order       = 2
}

data "coder_parameter" "ruby_version" {
  name         = "ruby_Version"
  display_name = "Ruby Version"
  description  = "Which version of Ruby? Must match a [ghcr.io/emboldagency/docker-ruby](https://github.com/emboldagency/docker-ruby/pkgs/container/docker-ruby) image tag."
  icon         = "/icon/ruby.png"
  type         = "string"
  default      = "3.4.9"
  mutable      = true
  order        = 3
  option {
    name  = "4.0.5"
    value = "4.0.5"
  }
  option {
    name  = "3.4.9"
    value = "3.4.9"
  }
  option {
    name  = "3.3.11"
    value = "3.3.11"
  }
  option {
    name  = "3.3.1"
    value = "3.3.1"
  }
  option {
    name  = "3.0.7"
    value = "3.0.7"
  }
}

data "coder_parameter" "postgres_version" {
  name         = "postgres_version"
  display_name = "Postgres Version"
  description  = "What version of Postgres? Must match a [postgres](https://hub.docker.com/_/postgres) image tag. \n\n_NOTE: Changing this without destroying the PG volume will cause the PG container to fail to start._"
  icon         = "/icon/postgres.svg"
  type         = "string"
  default      = "15"
  mutable      = true
  order        = 4
}

data "coder_parameter" "ubuntu_version" {
  name         = "ubuntu_version"
  display_name = "Ubuntu Version"
  description  = "Which version of Ubuntu? Must match an available [docker-base image tag](https://github.com/emboldagency/docker-base/pkgs/container/docker-base)."
  icon         = "/icon/ubuntu.svg"
  type         = "string"
  default      = "26.04"
  mutable      = true
  order        = 5
  option {
    name  = "24.04 LTS (Noble)"
    value = "24.04"
  }
  # Hide 26.04 when Ruby 3.0.x is selected. Ruby 3.0 predates Ubuntu 26.04's
  # toolchain (GCC 15, OpenSSL 3.5) and ruby-build doesn't auto-patch EOL'd
  # Rubies for new compilers, so this combination has no published image.
  dynamic "option" {
    for_each = startswith(data.coder_parameter.ruby_version.value, "3.0.") ? [] : [1]
    content {
      name  = "26.04 LTS (Resolute)"
      value = "26.04"
    }
  }
}

# ------------------------------------------------------------------------------
# Context Data & Locals
# ------------------------------------------------------------------------------

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Gates workspace creation on GitHub external-auth being authorized so that
# `coder external-auth access-token github` works at runtime. We intentionally
# do NOT inject .access_token into the agent/container env: it's a GitHub App
# user-to-server token (ghu_…) with a finite TTL, so a build-time snapshot goes
# stale while the workspace stays up. Tools fetch a fresh token at runtime
# instead (git via GIT_ASKPASS/coder gitssh; gh/vault via `coder external-auth`).
data "coder_external_auth" "github" {
  id = "github"
}

locals {
  app                   = lower(try(length(local.pulsar_app_name), 0) > 0 ? local.pulsar_app_name : local.workspace_name)
  db_hostname           = "postgres"
  db_key                = "Postgres"
  db_name               = replace(local.app, "-", "_")
  db_type               = "postgres"
  db_version            = local.postgres_version
  dev_url               = "https://webapp--${local.workspace_name}--${local.user_username}.embold.dev"
  dotfiles_uri          = try(length(data.coder_parameter.dotfiles_url.value) > 0, false) ? data.coder_parameter.dotfiles_url.value : try(module.dotfiles[0].dotfiles_uri, "")
  postgres_version      = data.coder_parameter.postgres_version.value
  pulsar_app_name       = data.coder_parameter.pulsar_app_name.value
  pulsar_magic_template = data.coder_parameter.pulsar_magic_template.value
  resource_name_base    = "coder-${local.user_username}-${local.workspace_name}"
  ruby_version          = data.coder_parameter.ruby_version.value
  template_version      = trimspace(file("${path.module}/VERSION"))
  timezone              = coalesce(module.timezone.timezone, "UTC")
  ubuntu_version        = data.coder_parameter.ubuntu_version.value
  user_email            = data.coder_workspace_owner.me.email
  user_full_name        = coalesce(data.coder_workspace_owner.me.full_name, local.user_username)
  user_id               = data.coder_workspace_owner.me.id
  user_username         = lower(data.coder_workspace_owner.me.name)
  workspace_id          = data.coder_workspace.me.id
  workspace_name        = lower(data.coder_workspace.me.name)
}

# ------------------------------------------------------------------------------
# Main Resources
# ------------------------------------------------------------------------------

resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"

  env = {
    APP                    = local.app
    CODER_TEMPLATE_VERSION = local.template_version
    CODER_USERNAME         = local.user_username
    CODER_WORKSPACE_NAME   = local.workspace_name
    CODER_WORKSPACE_PORT   = 3000
    DEVURL                 = local.dev_url
    DOTFILES_URL           = local.dotfiles_uri
    GIT_AUTHOR_NAME        = local.user_full_name
    GIT_AUTHOR_EMAIL       = local.user_email
    GIT_COMMITTER_NAME     = local.user_full_name
    GIT_COMMITTER_EMAIL    = local.user_email
    PULSAR_MAGIC_TEMPLATE  = local.pulsar_magic_template
    # Point the Playwright MCP at the shared browserless service (on coder-shared)
    # instead of installing a local Chromium. token must match the browserless stack.
    PLAYWRIGHT_MCP_CDP_ENDPOINT = "ws://browserless:3000?token=${var.playwright_token}"
  }

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 30
    timeout      = 1
    order        = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem --prefix 'Gi' | sed 's/ //;s/iB//'"
    interval     = 30
    timeout      = 1
    order        = 2
  }

  metadata {
    display_name = "Home Volume Size"
    key          = "home_volume_size"
    script       = "du -BG --apparent-size /home/embold | tail -1 | awk '{print $1}'"
    interval     = 300
    timeout      = 30
    order        = 3
  }

  metadata {
    display_name = "Database Size"
    key          = "postgres_volume_size"
    script       = "psql -U embold -d ${local.db_name} -c \"SELECT pg_size_pretty(pg_database_size('${local.db_name}'));\" -t | xargs"
    interval     = 300
    timeout      = 30
    order        = 4
  }

  # On-disk size of the Postgres volume (mounted read-only at /mnt/postgres-data).
  # Differs from "Database Size" (logical) by WAL, indexes overhead, and slack.
  metadata {
    display_name = "Database Disk Usage"
    key          = "postgres_disk_usage"
    script       = "du -BG --apparent-size /mnt/postgres-data 2>/dev/null | tail -1 | awk '{print $1}'"
    interval     = 300
    timeout      = 30
    order        = 5
  }

  startup_script = <<-EOT
    set -e
    /bin/bash /coder/scripts/configure
  EOT
}

resource "coder_app" "web_app" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  display_name = "Web App"
  slug         = "webapp"
  icon         = "https://api.embold.net/icons/fas-globe.svg"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "public"
  order        = 1
  open_in      = "tab"
}

resource "coder_script" "prepare_rails" {
  agent_id     = coder_agent.main.id
  display_name = "Prepare Rails"
  icon         = "/icon/rails.svg"
  run_on_start = true
  script       = <<-EOT
        set -e
        # Remove potentially stale Rails server.pid file
        if [ -f $HOME/code/$APP/tmp/pids/server.pid ]; then
          echo "Removing stale Rails server.pid file"
          rm -f $HOME/code/$APP/tmp/pids/server.pid
        fi
    EOT
}

resource "coder_script" "fix_ruby_binstubs" {
  agent_id     = coder_agent.main.id
  display_name = "Fix Ruby Binstubs"
  icon         = "/icon/ruby.png"
  run_on_start = true
  script       = <<-EOT
        set -e
        # Ensure bundler binstubs match the current Ruby version (fixes shebangs if version changes)
        if command -v ruby >/dev/null 2>&1 && [ -f "/coder/gems/ruby/$RUBY_VERSION/bin/bundle" ]; then
          current_ruby=$(ruby -e 'puts RUBY_VERSION')
          bundle_shebang=$(head -n1 "/coder/gems/ruby/$RUBY_VERSION/bin/bundle" 2>/dev/null || echo "")
          if [[ "$bundle_shebang" =~ ruby([0-9]+\.[0-9]+) ]]; then
            shebang_version="$${BASH_REMATCH[1]}"
            if [ "$shebang_version" != "$${current_ruby%.*}" ]; then
              echo "Ruby shebang mismatch detected; reinstalling bundler with correct version"
              gem install bundler --conservative --force
            fi
          fi
        fi
    EOT
}

# ------------------------------------------------------------------------------
# Networking & Volumes
# ------------------------------------------------------------------------------

resource "docker_network" "workspace" {
  count = data.coder_workspace.me.start_count
  name  = "${local.resource_name_base}-network"
}

resource "docker_volume" "home_volume" {
  name = "${local.resource_name_base}-${local.workspace_id}-home"

  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = local.user_username
  }
  labels {
    label = "coder.owner_id"
    value = local.user_id
  }
  labels {
    label = "coder.workspace_id"
    value = local.workspace_id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = local.workspace_name
  }
}

resource "docker_volume" "postgres_volume" {
  name = "${local.resource_name_base}-${local.workspace_id}-postgres"

  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = local.user_username
  }
  labels {
    label = "coder.owner_id"
    value = local.user_id
  }
  labels {
    label = "coder.workspace_id"
    value = local.workspace_id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = local.workspace_name
  }
}

# ------------------------------------------------------------------------------
# Containers
# ------------------------------------------------------------------------------

resource "docker_container" "postgres" {
  count        = data.coder_workspace.me.start_count
  name         = "${local.resource_name_base}-postgres"
  image        = "postgres:${local.postgres_version}"
  hostname     = "postgres"
  network_mode = docker_network.workspace[count.index].name
  env = [
    "POSTGRES_DB=${local.db_name}",
    "POSTGRES_USER=embold",
    "POSTGRES_PASSWORD=embold",
  ]
  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.postgres_volume.name
    read_only      = false
  }
  healthcheck {
    test = [
      "CMD-SHELL", "pg_isready -q -d ${local.db_name} -U embold"
    ]
    interval = "30s"
    timeout  = "5s"
    retries  = 3
  }
}

data "docker_registry_image" "ruby" {
  name = "ghcr.io/emboldagency/docker-ruby:${local.ruby_version}-ubuntu${local.ubuntu_version}-${local.template_version}"
}

resource "docker_image" "ruby" {
  name          = data.docker_registry_image.ruby.name
  pull_triggers = [data.docker_registry_image.ruby.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  name       = local.resource_name_base
  image      = docker_image.ruby.name
  hostname   = local.workspace_name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  # Multi-home: the per-workspace network (postgres/mailpit sidecars) plus the shared
  # `coder-shared` network for the browserless service. networks_advanced (not
  # network_mode) is required to attach to more than one network. NOTE: coder-shared
  # must exist first (deploy the browserless Portainer stack before pushing this).
  networks_advanced {
    name = docker_network.workspace[count.index].name
  }
  networks_advanced {
    name = "coder-shared"
  }
  # Run a real init (Docker's tini) as PID 1 so zombie reaping works; without it,
  # service restarts fail on first try. Baking tini into the image wouldn't help —
  # the entrypoint above overrides any image ENTRYPOINT.
  init = true

  env = compact([
    "APP=${local.app}",
    # No docker daemon/socket in workspaces; stops the agent's `docker ps`
    # probe that 500s the dashboard's /containers call.
    "CODER_AGENT_DEVCONTAINERS_ENABLE=false",
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DATABASE_URL=postgresql://embold:embold@postgres:5432/${local.db_name}",
    # No static GITHUB_TOKEN here on purpose — see data.coder_external_auth.github.
    "HOSTNAME=${local.app}",
    "PGHOST=postgres",
    "PGDATABASE=${local.db_name}",
    "PGUSER=embold",
    "PGPASSWORD=embold",
    "PULSAR_APP_NAME=${local.pulsar_app_name}",
    "RUBY_VERSION=${local.ruby_version}",
    "TZ=${local.timezone}"
  ])

  volumes {
    container_path = "/home/embold"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }

  # Read-only so the agent can `du` the DB volume for the disk-usage metric.
  # du only stats files, so RO access to the live datadir is safe.
  volumes {
    container_path = "/mnt/postgres-data"
    volume_name    = docker_volume.postgres_volume.name
    read_only      = true
  }

  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = local.user_username
  }
  labels {
    label = "coder.owner_id"
    value = local.user_id
  }
  labels {
    label = "coder.workspace_id"
    value = local.workspace_id
  }
  labels {
    label = "coder.workspace_name"
    value = local.workspace_name
  }
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id

  item {
    key   = "Ruby"
    value = local.ruby_version
  }

  item {
    key   = local.db_key
    value = local.db_version
  }
  item {
    key   = "Ubuntu"
    value = local.ubuntu_version
  }
  item {
    key   = "Image"
    value = basename(docker_image.ruby.name)
  }

  dynamic "item" {
    for_each = module.dynamic_services[0].connection_metadata
    content {
      key   = "Hostname (custom-${item.value.custom_index}, ${split(":", item.value.image)[0]})"
      value = item.value.hostname
    }
  }
}

# ------------------------------------------------------------------------------
# Modules
# ------------------------------------------------------------------------------

module "adminer" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/adminer?ref=v2026.06.22.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  db_server           = local.db_hostname
  db_username         = "embold"
  db_password         = "embold"
  db_name             = local.db_name
  db_driver           = "pgsql"
  proxy_mappings      = ["18080:adminer:8080"]
}

module "coder-login" {
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.1.0"
}

module "code-server" {
  source       = "https://registry.coder.com/modules/code-server"
  agent_id     = coder_agent.main.id
  folder       = "/home/embold/code/${local.app}"
  display_name = "VS Code Web"
  extensions   = []
  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }
}

module "dotfiles" {
  source          = "git::https://github.com/emboldagency/coder-registry.git//modules/dotfiles?ref=v2026.06.22.0"
  count           = data.coder_workspace.me.start_count
  agent_id        = coder_agent.main.id
  user            = "embold"
  parameter_order = 10 # 3 parameters
  manual_update   = true
  # Pass the deprecated dotfiles_url value so the module skips creating its own
  # parameter when a legacy value exists. On new workspaces the deprecated param
  # is empty so the module's parameter takes over.
  dotfiles_uri = try(length(data.coder_parameter.dotfiles_url.value) > 0, false) ? data.coder_parameter.dotfiles_url.value : null
}

module "dynamic_services" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/dynamic-resources?ref=v2026.06.22.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  parameter_order     = 30 # 34 parameters (pushed towards end)
}

module "home_setup" {
  source     = "git::https://github.com/emboldagency/coder-registry.git//modules/home-setup?ref=v2026.06.22.0"
  count      = data.coder_workspace.me.start_count
  agent_id   = coder_agent.main.id
  source_dir = "/coder/home"
  target_dir = "/home/embold"
}

module "jetbrains_gateway" {
  source         = "https://registry.coder.com/modules/jetbrains-gateway"
  agent_id       = coder_agent.main.id
  agent_name     = local.workspace_name
  folder         = "/home/embold/code/${local.app}"
  jetbrains_ides = ["RM"]
  default        = "RM"
}

module "mailpit" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/mailpit?ref=v2026.06.22.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  proxy_mappings      = ["18025:mailpit:8025"]
}

module "ssh_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/ssh-setup?ref=v2026.06.22.0"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.main.id
  hosts = [
    "github.com",
    "embold.net",
    "coder.ssh.embold.net:2022",
    "8.42.149.40:2022",
    "maintenance.ssh.embold.net:3022",
    "8.42.149.40:3022",
    "staging.ssh.embold.net:22",
    "8.42.149.41:22",
  ]
}

module "timezone" {
  source          = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=v2026.06.22.0"
  agent_id        = coder_agent.main.id
  parameter_order = 7 # 1 parameter
}

module "vault" {
  source     = "registry.coder.com/coder/vault-github/coder"
  version    = "1.1.2"
  count      = data.coder_workspace.me.start_count
  agent_id   = coder_agent.main.id
  vault_addr = "https://vault.embold.dev"
  # Pin to the vault binary baked into the workspace image so the vault-github
  # module finds a matching version already present and skips its per-boot
  # download. Keep in sync with VAULT_VERSION in docker-base when you bump it
  # (a mismatch is harmless, it just triggers one redundant download at start).
  vault_cli_version = "2.0.2"
}

# Retry backstop for the vault module above. That module's login script makes a
# single attempt (fetch external-auth token, one `vault login`) and exits on any
# transient GitHub-API or token-refresh blip, leaving no cached token. This
# re-runs the login with backoff only if the module didn't leave a valid token.
# Non-fatal by design: it always exits 0 so a sealed/unreachable Vault never
# blocks workspace start (downstream Vault reads already skip gracefully).
resource "coder_script" "vault_login_retry" {
  count              = data.coder_workspace.me.start_count
  agent_id           = coder_agent.main.id
  display_name       = "Vault login (retry backstop)"
  icon               = "/icon/vault.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/usr/bin/env bash
    set -uo pipefail
    export VAULT_ADDR="https://vault.embold.dev"

    # If the vault module already cached a valid token, there is nothing to do.
    if vault token lookup >/dev/null 2>&1; then
      echo "Vault token already valid; retry backstop not needed."
      exit 0
    fi

    for attempt in 1 2 3; do
      echo "Vault login backstop attempt $attempt/3..."
      if token=$(coder external-auth access-token github 2>/dev/null) \
        && [ -n "$token" ] \
        && vault login -no-print -method=github -path=github token="$token" >/dev/null 2>&1; then
        echo "Vault login succeeded on backstop attempt $attempt."
        exit 0
      fi
      sleep $((attempt * 3))
    done

    echo "Vault login backstop exhausted after 3 attempts; downstream Vault reads will skip." >&2
    exit 0
  EOT
}

# DEPRECATED: Keep this parameter for backward compatibility with workspaces
# created before the dotfiles module was introduced. Existing workspaces have a
# stored value under the name "dotfiles URL" — removing it breaks upgrades.
# TODO: Remove this parameter once all workspaces have been upgraded.
data "coder_parameter" "dotfiles_url" {
  name        = "dotfiles URL"
  description = "GitHub repository with dotfiles (deprecated — use Dotfiles URL above)"
  icon        = "/icon/dotfiles.svg"
  type        = "string"
  default     = ""
  mutable     = true
  order       = 150
}
