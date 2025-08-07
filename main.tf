terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.5.3"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.1"
    }
  }
}

provider "coder" {}

data "coder_external_auth" "github" {
  id = "github"
}

provider "docker" {
  registry_auth {
    address  = "registry-1.docker.io"
    username = "emboldcreative"
    password = var.DOCKER_REGISTRY_PASS
  }
}

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

locals {
  app                   = lower(try(length(local.pulsar_app_name), 0) > 0 ? local.pulsar_app_name : local.workspace_name)
  db_name               = replace(local.app, "-", "_")
  dev_url               = "https://webapp--main--${local.workspace_name}--${local.user_username}.embold.dev"
  dotfiles_url          = data.coder_parameter.dotfiles_url.value
  github_token          = data.coder_external_auth.github.access_token
  postgres_version      = data.coder_parameter.postgres_version.value
  pulsar_app_name       = data.coder_parameter.pulsar_app_name.value
  pulsar_magic_template = data.coder_parameter.pulsar_magic_template.value
  resource_name_prefix  = "coder-${local.user_username}-${local.workspace_name}"
  template_version      = "v1.0.0"
  rails_master_key      = trimspace(data.coder_parameter.rails_master_key.value) != "" ? "RAILS_MASTER_KEY=${trimspace(data.coder_parameter.rails_master_key.value)}" : ""
  ruby_version          = data.coder_parameter.ruby_version.value
  ubuntu_version        = data.coder_parameter.ubuntu_version.value
  user_email            = data.coder_workspace_owner.me.email
  user_full_name        = coalesce(data.coder_workspace_owner.me.full_name, local.user_username)
  user_id               = data.coder_workspace_owner.me.id
  user_username         = lower(data.coder_workspace_owner.me.name)
  workspace_id          = data.coder_workspace.me.id
  workspace_name        = lower(data.coder_workspace.me.name)
}

variable "DOCKER_REGISTRY_PASS" {
  sensitive = true
}

data "coder_parameter" "dotfiles_url" {
  name        = "dotfiles URL"
  description = "GitHub repository with dotfiles"
  mutable     = true
}

data "coder_parameter" "pulsar_app_name" {
  name        = "Pulsar App Name"
  description = "What is the Pulsar app name? If this is blank, the workspace name will be used."
  icon        = "/icon/coder.svg"
  type        = "string"
  default     = ""
  mutable     = true
}

data "coder_parameter" "pulsar_magic_template" {
  name        = "Pulsar Magic Template?"
  description = "Should we use the Pulsar magic template to dynamically build the Pulsar configuration?"
  type        = "bool"
  icon        = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 576 512'%3E%3C!--!Font Awesome Free 6.7.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2024 Fonticons, Inc.--%3E%3Cpath fill='%23009dff' d='M234.7 42.7L197 56.8c-3 1.1-5 4-5 7.2s2 6.1 5 7.2l37.7 14.1L248.8 123c1.1 3 4 5 7.2 5s6.1-2 7.2-5l14.1-37.7L315 71.2c3-1.1 5-4 5-7.2s-2-6.1-5-7.2L277.3 42.7 263.2 5c-1.1-3-4-5-7.2-5s-6.1 2-7.2 5L234.7 42.7zM46.1 395.4c-18.7 18.7-18.7 49.1 0 67.9l34.6 34.6c18.7 18.7 49.1 18.7 67.9 0L529.9 116.5c18.7-18.7 18.7-49.1 0-67.9L495.3 14.1c-18.7-18.7-49.1-18.7-67.9 0L46.1 395.4zM484.6 82.6l-105 105-23.3-23.3 105-105 23.3 23.3zM7.5 117.2C3 118.9 0 123.2 0 128s3 9.1 7.5 10.8L64 160l21.2 56.5c1.7 4.5 6 7.5 10.8 7.5s9.1-3 10.8-7.5L128 160l56.5-21.2c4.5-1.7 7.5-6 7.5-10.8s-3-9.1-7.5-10.8L128 96 106.8 39.5C105.1 35 100.8 32 96 32s-9.1 3-10.8 7.5L64 96 7.5 117.2zm352 256c-4.5 1.7-7.5 6-7.5 10.8s3 9.1 7.5 10.8L416 416l21.2 56.5c1.7 4.5 6 7.5 10.8 7.5s9.1-3 10.8-7.5L480 416l56.5-21.2c4.5-1.7 7.5-6 7.5-10.8s-3-9.1-7.5-10.8L480 352l-21.2-56.5c-1.7-4.5-6-7.5-10.8-7.5s-9.1 3-10.8 7.5L416 352l-56.5 21.2z'/%3E%3C/svg%3E" # font-awesome magic wand. alt: "/emojis/1fa84.png"
  default     = false
  mutable     = true
}

data "coder_parameter" "ruby_version" {
  name        = "Ruby Version"
  description = "Which version of Ruby? Must match a emboldcreative/ruby image tag on DockerHub"
  icon        = "/icon/ruby.png"
  type        = "string"
  default     = "3.3.4"
  mutable     = true
}

data "coder_parameter" "postgres_version" {
  name        = "Postgres Version"
  description = "What version of Postgres? Must match an official mariadb image tag on DockerHub. NOTE: Changing this without destroying the PG volume will cause the PG container to fail to start"
  icon        = "/icon/database.svg"
  type        = "string"
  default     = "15"
  mutable     = true
}

data "coder_parameter" "ubuntu_version" {
  name        = "Ubuntu Version"
  description = "Which version of Ubuntu? Must match a emboldcreative/base image tag on DockerHub"
  icon        = "/icon/ubuntu.svg"
  type        = "string"
  default     = "24.04"
  mutable     = true
  option {
    name  = "24.04 LTS (Noble)"
    value = "24.04"
  }
  option {
    name  = "22.04 LTS (Jammy)"
    value = "22.04"
  }
}

data "coder_parameter" "rails_master_key" {
  name        = "Rails Master Key"
  description = "Enter the rails master key to use for encrypted credentials. This will set the RAILS_MASTER_KEY environment variable."
  icon        = "/emojis/1f511.png"
  type        = "string"
  default     = ""
  mutable     = true
}

resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"
  env = {
    APP                   = local.app
    CODER_USERNAME        = local.user_username
    CODER_WORKSPACE_NAME  = local.workspace_name
    CODER_WORKSPACE_PORT  = 3000
    DEVURL                = local.dev_url
    DOTFILES_URL          = local.dotfiles_url
    GIT_AUTHOR_NAME       = local.user_full_name
    GIT_AUTHOR_EMAIL      = local.user_email
    GIT_COMMITTER_NAME    = local.user_full_name
    GIT_COMMITTER_EMAIL   = local.user_email
    PULSAR_MAGIC_TEMPLATE = local.pulsar_magic_template
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
    script       = "psql -U embold -d labspend -c \"SELECT pg_size_pretty(pg_database_size('labspend'));\" -t | xargs"
    interval     = 300
    timeout      = 30
    order        = 4
  }
  startup_script = <<-EOT
        set -e
        /bin/bash /coder/scripts/configure
    EOT
}

resource "docker_volume" "home_volume" {
  name = "${local.resource_name_prefix}-${local.workspace_id}-home"
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
  name = "${local.resource_name_prefix}-${local.workspace_id}-postgres"
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

resource "docker_volume" "redis_volume" {
  name = "${local.resource_name_prefix}-${local.workspace_id}-redis"
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

resource "docker_network" "workspace" {
  name  = "${local.resource_name_prefix}-network"
  count = data.coder_workspace.me.start_count
}

resource "docker_container" "postgres" {
  count        = data.coder_workspace.me.start_count
  name         = "${local.resource_name_prefix}-postgres"
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
      "CMD-SHELL", "pg_isready", "-q", "-d labspend", "-U embold",
    ]
    interval = "30s"
    timeout  = "5s"
    retries  = 3
  }
  ports {
    internal = 5432
    external = 5432
  }

  restart = "unless-stopped"
}

data "docker_registry_image" "ruby" {
  name = "emboldcreative/ruby:${local.ruby_version}-ubuntu${local.ubuntu_version}"
}

resource "docker_image" "ruby" {
  name          = data.docker_registry_image.ruby.name
  pull_triggers = [data.docker_registry_image.ruby.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = docker_image.ruby.name
  name       = local.resource_name_prefix
  hostname   = local.workspace_name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = compact([
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DATABASE_URL=postgresql://embold:embold@postgres:5432/${local.db_name}",
    "GITHUB_TOKEN=${local.github_token}",
    "HOSTNAME=${local.app}",
    "PGHOST=postgres",
    "PGDATABASE=${local.db_name}",
    "PGUSER=embold",
    "PGPASSWORD=embold",
    "RUBY_VERSION=${local.ruby_version}",
    "${local.rails_master_key}",
  ])
  volumes {
    container_path = "/home/embold"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  network_mode = docker_network.workspace[count.index].name
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

resource "coder_app" "mailpit" {
  agent_id     = coder_agent.main.id
  slug         = "mailpit"
  display_name = "Mailpit"
  url          = "http://localhost:8025"
  icon         = "https://mailpit.axllent.org/images/mailpit.svg"
  # order        = var.order
}


resource "docker_image" "adminer" {
  name = "adminer:latest"
}
resource "docker_container" "adminer" {
  name  = "labspend-adminer"
  image = docker_image.adminer.name
  ports {
    internal = 8080
    external = 8080
  }
}
resource "coder_app" "adminer" {
  agent_id     = coder_agent.main.id
  slug         = "adminer"
  display_name = "Adminer"
  url          = "http://localhost:8080"
  icon         = "https://www.adminer.org/static/images/logo.png"
  # order        = var.order != null ? var.order + 1 : null
}

resource "coder_app" "web_app" {
  agent_id     = coder_agent.main.id
  display_name = "Web App"
  slug         = "webapp"
  icon         = "/emojis/1f310.png"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "public"
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id
  item {
    key   = "Ruby"
    value = local.ruby_version
  }
  item {
    key   = "Postgres"
    value = local.postgres_version
  }
  item {
    key   = "Ubuntu"
    value = local.ubuntu_version
  }
  item {
    key   = "Image"
    value = basename(docker_image.ruby.name)
  }
}

module "code-server" {
  display_name = "VS Code Web"
  source       = "https://registry.coder.com/modules/code-server"
  agent_id     = coder_agent.main.id
  folder       = "/home/embold/code/${local.app}"
  extensions   = []
  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }
}

module "jetbrains" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jetbrains/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
  folder   = "/home/embold/code/${local.app}"
  default  = ["RM"]
}
