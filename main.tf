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

# ------------------------------------------------------------------------------
# Coder Parameters
# ------------------------------------------------------------------------------

data "coder_parameter" "pulsar_app_name" {
  name        = "Pulsar App Name"
  description = "What is the Pulsar app name? If this is blank, the workspace name will be used."
  icon        = "https://api.embold.net/icons/?name=title.svg&color=009dff"
  type        = "string"
  default     = ""
  mutable     = true
  order       = 1
}

data "coder_parameter" "pulsar_magic_template" {
  name        = "Pulsar Magic Template?"
  description = "Should we use the Pulsar magic template to dynamically build the Pulsar configuration?"
  type        = "bool"
  icon        = "https://api.embold.net/icons/?name=fas-magic-wand.svg&color=009dff"
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
  default      = "4.0.1"
  mutable      = true
  order        = 3
  option {
    name  = "4.0.1"
    value = "4.0.1"
  }
  option {
    name  = "3.4.9"
    value = "3.4.9"
  }
  option {
    name  = "3.3.10"
    value = "3.3.10"
  }
  option {
    name  = "3.2.10"
    value = "3.2.10"
  }
  option {
    name  = "3.1.7"
    value = "3.1.7"
  }
  option {
    name  = "3.0.7"
    value = "3.0.7"
  }
  option {
    name  = "2.7.8"
    value = "2.7.8"
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
  default      = "24.04"
  mutable      = true
  order        = 5
  option {
    name  = "24.04 LTS (Noble)"
    value = "24.04"
  }
}

data "coder_parameter" "rails_master_key" {
  name         = "rails_master_key"
  display_name = "Rails Master Key"
  description  = "Enter the rails master key to use for encrypted credentials. This will set the RAILS_MASTER_KEY environment variable."
  type         = "string"
  icon         = "https://api.embold.net/icons/?name=fas-key.svg&color=009dff"
  default      = ""
  mutable      = true
  order        = 6
}

# ------------------------------------------------------------------------------
# Context Data & Locals
# ------------------------------------------------------------------------------

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

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
  github_token          = data.coder_external_auth.github.access_token
  postgres_version      = data.coder_parameter.postgres_version.value
  pulsar_app_name       = data.coder_parameter.pulsar_app_name.value
  pulsar_magic_template = data.coder_parameter.pulsar_magic_template.value
  rails_master_key      = trimspace(data.coder_parameter.rails_master_key.value) != "" ? "RAILS_MASTER_KEY=${trimspace(data.coder_parameter.rails_master_key.value)}" : ""
  resource_name_base    = "coder-${local.user_username}-${local.workspace_name}"
  ruby_version          = data.coder_parameter.ruby_version.value
  template_version      = "2026.03.12.0"
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
  icon         = "https://api.embold.net/icons/?name=fas-globe.svg&color=009dff"
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
  count        = data.coder_workspace.me.start_count
  name         = local.resource_name_base
  image        = docker_image.ruby.name
  hostname     = local.workspace_name
  entrypoint   = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  network_mode = docker_network.workspace[count.index].name

  env = compact([
    "APP=${local.app}",
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DATABASE_URL=postgresql://embold:embold@postgres:5432/${local.db_name}",
    "GITHUB_TOKEN=${local.github_token}",
    "HOSTNAME=${local.app}",
    "PGHOST=postgres",
    "PGDATABASE=${local.db_name}",
    "PGUSER=embold",
    "PGPASSWORD=embold",
    "PULSAR_APP_NAME=${local.pulsar_app_name}",
    "RUBY_VERSION=${local.ruby_version}",
    "${local.rails_master_key}",
    "TZ=${local.timezone}"
  ])

  volumes {
    container_path = "/home/embold"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
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
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/adminer?ref=v2026.03.11.0"
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
  source          = "git::https://github.com/emboldagency/coder-registry.git//modules/dotfiles?ref=v2026.03.11.0"
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
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/dynamic-resources?ref=v2026.03.11.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  parameter_order     = 30 # 34 parameters (pushed towards end)
}

module "home_setup" {
  source     = "git::https://github.com/emboldagency/coder-registry.git//modules/home-setup?ref=v2026.03.11.0"
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

module "antigravity" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/antigravity/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
}

module "mailpit" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/mailpit?ref=v2026.03.11.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  proxy_mappings      = ["18025:mailpit:8025"]
}

module "ssh_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/ssh-setup?ref=v2026.03.11.0"
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
  source          = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=v2026.03.11.0"
  agent_id        = coder_agent.main.id
  parameter_order = 7 # 1 parameter
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
