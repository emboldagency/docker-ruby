terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 1.0.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
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
  app              = lower(try(length(local.pulsar_app_name), 0) > 0 ? local.pulsar_app_name : local.workspace_name)
  db_name          = replace(local.app, "-", "_")
  dev_url          = "https://webapp--main--${local.workspace_name}--${local.user_username}.embold.dev"
  postgres_version = data.coder_parameter.postgres_version.value
  pulsar_app_name  = data.coder_parameter.pulsar_app_name.value
  rails_master_key = data.coder_parameter.rails_master_key.value != "" ? format("RAILS_MASTER_KEY=%s", data.coder_parameter.rails_master_key.value) : ""
  ruby_version     = data.coder_parameter.ruby_version
  ubuntu_version   = data.coder_parameter.ubuntu_version.value
  user_email       = data.coder_workspace_owner.me.email
  user_full_name   = coalesce(data.coder_workspace_owner.me.full_name, local.user_username)
  user_id          = data.coder_workspace_owner.me.id
  user_username    = lower(data.coder_workspace_owner.me.name)
  workspace_id     = data.coder_workspace.me.id
  workspace_name   = lower(data.coder_workspace.me.name)
}

variable "DOCKER_REGISTRY_PASS" {
  sensitive = true
}

data "coder_parameter" "pulsar_app_name" {
  name        = "Pulsar App Name"
  description = "What is the pulsar app name? If this is blank, the workspace name will be used."
  icon        = "/icon/coder.svg"
  type        = "string"
  default     = ""
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
    APP                  = local.app
    CODER_USERNAME       = local.user_username
    CODER_WORKSPACE_NAME = local.workspace_name
    CODER_WORKSPACE_PORT = 3000
    DEVURL               = local.dev_url
    GIT_AUTHOR_NAME      = local.user_full_name
    GIT_AUTHOR_EMAIL     = local.user_email
    GIT_COMMITTER_NAME   = local.user_full_name
    GIT_COMMITTER_EMAIL  = local.user_email
  }
  startup_script = <<-EOT
        set -e
        /bin/bash /coder/scripts/configure
    EOT
}

resource "docker_volume" "home_volume" {
  name = "coder-${local.user_username}-${local.workspace_name}-${local.workspace_id}-home"
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
  name = "coder-${local.user_username}-${local.workspace_name}-${local.workspace_id}-postgres"
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
  name  = "coder-${local.user_username}-${local.workspace_name}-network"
  count = data.coder_workspace.me.start_count
}

resource "docker_container" "pg" {
  count        = data.coder_workspace.me.start_count
  name         = "coder-${local.user_username}-${local.workspace_name}-pg"
  image        = "postgres:${local.postgres_version}"
  hostname     = "postgres"
  network_mode = docker_network.workspace[count.index].name
  env = [
    "POSTGRES_ROOT_PASSWORD=embold",
    "POSTGRES_DB=${local.db_name}",
    "POSTGRES_USER=embold",
    "POSTGRES_PASSWORD=embold",
  ]
  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.postgres_volume.name
    read_only      = false
  }
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
  count = data.coder_workspace.me.start_count
  image = docker_image.ruby.name
  name       = "coder-${local.user_username}-${local.workspace_name}"
  hostname = local.workspace_name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = compact([
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "PGDATABASE=${local.db_name}",
    "PGHOST=postgres",
    "PGPASSWORD=embold",
    "PGUSER=embold",
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
    key   = "image"
    value = basename(docker_image.ruby.name)
  }
  item {
    key   = "devurl"
    value = local.dev_url
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

module "jetbrains_gateway" {
  source         = "https://registry.coder.com/modules/jetbrains-gateway"
  agent_id       = coder_agent.main.id
  agent_name     = local.workspace_name
  folder         = "/home/embold/code/${local.app}"
  jetbrains_ides = ["RM"]
  default        = "RM"
}
