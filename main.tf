# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
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

# =============================================================================
# PROVIDERS
# =============================================================================
provider "coder" {}

provider "docker" {
  registry_auth {
    address  = "ghcr.io"
    username = "emboldagency"
    password = var.GHP_REGISTRY_PASS
  }
}

# =============================================================================
# VARIABLES
# =============================================================================
variable "GHP_REGISTRY_PASS" {
  sensitive = true
}

# =============================================================================
# DATA SOURCES
# =============================================================================
data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_external_auth" "github" {
  id = "github"
}

# =============================================================================
# PARAMETERS
# =============================================================================
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
  default      = "3.4.6"
  mutable      = true
  order        = 3
  option {
    name  = "3.4.6"
    value = "3.4.6"
  }
  option {
    name  = "3.3.9"
    value = "3.3.9"
  }
  option {
    name  = "3.2.9"
    value = "3.2.9"
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

data "coder_parameter" "ubuntu_version" {
  name         = "ubuntu_version"
  display_name = "Ubuntu Version"
  description  = "Which version of Ubuntu? Must match a [ghcr.io/emboldagency/docker-base](https://github.com/emboldagency/docker-base/pkgs/container/docker-base) image tag."
  icon         = "/icon/ubuntu.svg"
  type         = "string"
  default      = "24.04"
  mutable      = true
  order        = 4
  option {
    name  = "24.04 LTS (Noble)"
    value = "24.04"
  }
  option {
    name  = "22.04 LTS (Jammy)"
    value = "22.04"
  }
}

data "coder_parameter" "postgres_version" {
  name         = "postgres_version"
  display_name = "Postgres Version"
  description  = "What version of Postgres? Must match an official postgres image tag on DockerHub. \n\n_NOTE: Changing this without destroying the PG volume will cause the PG container to fail to start._"
  icon         = "/icon/postgres.svg"
  type         = "string"
  default      = "15"
  mutable      = true
  order        = 5
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

# =============================================================================
# LOCALS
# =============================================================================
locals {
  app                   = lower(try(length(local.pulsar_app_name), 0) > 0 ? local.pulsar_app_name : local.workspace_name)
  db_hostname           = "postgres"
  db_key                = "Postgres"
  db_name               = replace(local.app, "-", "_")
  db_type               = "postgres"
  db_version            = local.postgres_version
  dev_url               = "https://webapp--main--${local.workspace_name}--${local.user_username}.embold.dev"
  github_token          = data.coder_external_auth.github.access_token
  postgres_version      = coalesce(data.coder_parameter.postgres_version.value, "16")
  pulsar_app_name       = data.coder_parameter.pulsar_app_name.value
  pulsar_magic_template = data.coder_parameter.pulsar_magic_template.value
  rails_master_key      = trimspace(data.coder_parameter.rails_master_key.value) != "" ? "RAILS_MASTER_KEY=${trimspace(data.coder_parameter.rails_master_key.value)}" : ""
  resource_name_base    = "coder-${local.user_username}-${local.workspace_name}-${local.workspace_id}"
  ruby_version          = data.coder_parameter.ruby_version.value
  template_version      = "2026.02.25.0"
  timezone              = try(module.timezone[0].timezone, "UTC")
  ubuntu_version        = data.coder_parameter.ubuntu_version.value
  user_email            = data.coder_workspace_owner.me.email
  user_full_name        = coalesce(data.coder_workspace_owner.me.full_name, local.user_username)
  user_id               = data.coder_workspace_owner.me.id
  user_username         = lower(data.coder_workspace_owner.me.name)
  workspace_id          = data.coder_workspace.me.id
  workspace_name        = lower(data.coder_workspace.me.name)
}

# =============================================================================
# CODER AGENTS
# =============================================================================
resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  dir                     = "/home/embold/code/${local.workspace_name}"
  os                      = "linux"
  startup_script_behavior = "blocking"
  env = {
    APP                    = local.app
    CODER_TEMPLATE_VERSION = local.template_version
    CODER_USERNAME         = local.user_username
    CODER_WORKSPACE_NAME   = local.workspace_name
    CODER_WORKSPACE_PORT   = 3000
    DEVURL                 = local.dev_url
    GIT_AUTHOR_EMAIL       = local.user_email
    GIT_AUTHOR_NAME        = local.user_full_name
    GIT_COMMITTER_EMAIL    = local.user_email
    GIT_COMMITTER_NAME     = local.user_full_name
    PULSAR_MAGIC_TEMPLATE  = local.pulsar_magic_template
    GITHUB_TOKEN           = data.coder_external_auth.github.access_token
    TZ                     = local.timezone
  }
  startup_script = <<-EOT
        set -e

        embold='H4sIAAAAAAAAA52SMQ7DMAhFd5+CqWPv0itkyFDJErbk+h+/wcTGtM7Q/iUKmCf4QLRWNW0XT5YKV4k660cggJtFdmAAifgPIJCBJ0Q5vwQPA6YBtH6TpUXJZYIAlHkiZ6BN/Piw4BM4qAGdpMzO8x5G61TLvzvs32DNdTDy5GF/bsuZ/j1QY6F11hZjzAXQVy2B6uIBlGCzjs6RCx3MeeJUnfWjWpMuw+IhZQWRjb27iuiXmegSeGz5PvZb5AQLUcl7G2XjGNmfIEde3V7lWLfzZXgDYVxqC3sDAAA='
        base64 -d <<<"$embold" | gunzip
        echo
    EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 30
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  # TODO: Re-enable this at some point
  # metadata {
  #   display_name = "Database Size"
  #   key          = "postgres_volume_size"
  #   script       = "psql -U embold -d labspend -c \"SELECT pg_size_pretty(pg_database_size('labspend'));\" -t | xargs"
  #   interval     = 300
  #   timeout      = 30
  #   order        = 4
  # }
}

# =============================================================================
# CODER SCRIPTS & MODULES
# =============================================================================
module "timezone" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/timezone?ref=v2026.02.25.0"
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
}

module "ssh_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/ssh-setup?ref=v2026.02.25.0"
  agent_id = coder_agent.main.id
  hosts = [
    "coder.ssh.embold.net:2022",
    "8.42.149.40:2022",
    "maintenance.ssh.embold.net:3022",
    "8.42.149.40:3022",
    "staging.ssh.embold.net:22",
    "8.42.149.41:22",
  ]
}

module "home_setup" {
  source   = "git::https://github.com/emboldagency/coder-registry.git//modules/home-setup?ref=v2026.02.25.0"
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
}

module "dotfiles" {
  source          = "git::https://github.com/emboldagency/coder-registry.git//modules/dotfiles?ref=v2026.02.25.0"
  count           = data.coder_workspace.me.start_count
  agent_id        = coder_agent.main.id
  user            = "embold"
  parameter_order = 10
}

module "coder-login" {
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.1.0"
}

module "code-server" {
  count        = data.coder_workspace.me.start_count
  source       = "registry.coder.com/coder/code-server/coder"
  version      = "~> 1.0"
  agent_id     = coder_agent.main.id
  display_name = "VS Code Web"
  folder       = "/home/embold/code/${local.app}"
  order        = 1
}

module "git-config" {
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "1.0.15"
}

module "github-upload-public-key" {
  agent_id = coder_agent.main.id
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/github-upload-public-key/coder"
  version  = "1.0.31"
}

module "jetbrains" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jetbrains/coder"
  agent_id = coder_agent.main.id
  version  = "~> 1.0"
  folder   = "/home/embold/code/${local.app}"
  default  = ["RM"]
}

module "mailpit" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/mailpit?ref=v2026.02.25.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
}

module "dynamic_services" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/dynamic-resources?ref=v2026.02.25.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
}

module "adminer" {
  source              = "git::https://github.com/emboldagency/coder-registry.git//modules/adminer?ref=v2026.02.25.0"
  count               = data.coder_workspace.me.start_count
  agent_id            = coder_agent.main.id
  docker_network_name = docker_network.workspace[0].name
  resource_name_base  = local.resource_name_base
  db_name             = local.db_name
  db_driver           = "server"
  proxy_mappings      = ["18080:adminer:8080"]
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

# =============================================================================
# DOCKER INFRASTRUCTURE
# =============================================================================
resource "docker_network" "workspace" {
  name  = "${local.resource_name_base}-network"
  count = data.coder_workspace.me.start_count
}

resource "docker_volume" "home_volume" {
  name = "${local.resource_name_base}-home"
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
  count = data.coder_workspace.me.start_count
  name  = "${local.resource_name_base}-postgres"
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

resource "docker_volume" "mailpit_volume" {
  count = data.coder_workspace.me.start_count
  name  = "${local.resource_name_base}-mailpit"
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

# =============================================================================
# DOCKER IMAGES
# =============================================================================
data "docker_registry_image" "ruby" {
  name = "ghcr.io/emboldagency/docker-ruby:${local.ruby_version}-ubuntu${local.ubuntu_version}-release${local.template_version}"
}

resource "docker_image" "ruby" {
  name          = data.docker_registry_image.ruby.name
  pull_triggers = [data.docker_registry_image.ruby.sha256_digest]
  keep_locally  = true
}



# =============================================================================
# DOCKER CONTAINERS
# =============================================================================
resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = docker_image.ruby.name
  name       = local.resource_name_base
  hostname   = local.workspace_name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = compact([
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DATABASE_URL=postgresql://embold:embold@postgres:5432/${local.db_name}",
    "DOTFILES_URL=${module.dotfiles[count.index].dotfiles_uri}",
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
    volume_name    = docker_volume.postgres_volume[count.index].name
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
}



# =============================================================================
# CODER APPS & UI
# =============================================================================
resource "coder_app" "web_app" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  display_name = "Web App"
  slug         = "webapp"
  icon         = "https://api.embold.net/icons/?name=fas-globe.svg&color=009dff"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "public"
  order        = 2
  open_in      = "tab"
}




# =============================================================================
# METADATA & MONITORING
# =============================================================================
resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id

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

  item {
    key   = "Template"
    value = local.template_version
  }
}
