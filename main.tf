terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.18.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "coder" {
}

provider "docker" {
  registry_auth {
    address  = "registry-1.docker.io"
    username = "emboldcreative"
    password = var.DOCKER_REGISTRY_PASS
  }
}

data "coder_provisioner" "me" {
}

data "coder_workspace" "me" {
}

# data "coder_external_auth" "github" {
#   # Matches the ID of the git auth provider in Coder.
#   id = "github"
# }

locals {
  devurl      = "https://webapp--main--${data.coder_workspace.me.name}--${data.coder_workspace.me.owner}.embold.dev"
  app         = try(length(data.coder_parameter.pulsar_app_name.value), 0) > 0 ? data.coder_parameter.pulsar_app_name.value : data.coder_workspace.me.name
  postgres_db = replace(local.app, "-", "_")
  gem_home    = "/home/embold/.gems/${data.coder_parameter.ruby_version.value}"
}

variable "DOCKER_REGISTRY_PASS" {
  sensitive = true
}

data "coder_parameter" "pulsar_app_name" {
  name        = "Pulsar App Name"
  description = "What is the pulsar app name?"
  icon        = "/icon/coder.svg"
  type        = "string"
  mutable     = false
}

data "coder_parameter" "ubuntu_version" {
  name        = "Ubuntu Version"
  description = "Which version of Ubuntu?"
  icon        = "/icon/ubuntu.svg"
  type        = "string"
  default     = "22.04"
  mutable     = true

  option {
    name  = "24.04 LTS (Noble)"
    value = "24.04"
  }

  option {
    name  = "22.04 LTS (Jammy)"
    value = "22.04"
  }

  option {
    name  = "20.04 LTS (Focal)"
    value = "20.04"
  }
}

data "coder_parameter" "ruby_version" {
  name        = "Ruby Version"
  description = "Which version of Ruby?"
  icon        = "/icon/ruby.png"
  type        = "string"
  default     = "3.0.2"
  mutable     = true
  option {
    name  = "3.3.0"
    value = "3.3.0"
  }
  option {
    name  = "3.2.3"
    value = "3.2.3"
  }
  option {
    name  = "3.1.4"
    value = "3.1.4"
  }
  option {
    name  = "3.0.6"
    value = "3.0.6"
  }
  option {
    name  = "3.0.2"
    value = "3.0.2"
  }
}

data "coder_parameter" "postgres_version" {
  name        = "Postgres Version"
  description = "Should match a DockerHub tag for the Postgres image."
  icon        = "/icon/database.svg"
  type        = "string"
  default     = "16"
  mutable     = true
}

# data "coder_parameter" "rails_master_key" {
#   name        = "Rails Master Key"
#   description = "Enter the rails master key to "
#   icon        = "emojis/1f511.png"
#   type        = "string"
#   default     = ""
#   mutable     = true
# }

resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
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
    display_name = "Disk Usage"
    key          = "2_disk_usage"
    script       = "df -h | awk '$6 ~ /^\\/$/ { print $5 }'"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Load Average"
    key          = "3_load_average"
    script       = <<EOT
            awk '{print $1,$2,$3}' /proc/loadavg
        EOT
    interval     = 10
    timeout      = 1
  }
  env = {
    "APP"                  = local.app
    "CODER_USERNAME"       = data.coder_workspace.me.owner
    "CODER_WORKSPACE_NAME" = data.coder_workspace.me.name
    "CODER_WORKSPACE_PORT" = 3000
    "DEVURL"               = local.devurl
    "GIT_AUTHOR_EMAIL"     = data.coder_workspace.me.owner_email
    "GIT_AUTHOR_NAME"      = data.coder_workspace.me.owner
    "GIT_COMMITTER_EMAIL"  = data.coder_workspace.me.owner_email
    "GIT_COMMITTER_NAME"   = data.coder_workspace.me.owner
    # "GITHUB_TOKEN"         = data.coder_git_auth.github.access_token
  }
  startup_script = <<-EOT
        set -e
        /bin/bash /coder/scripts/configure
    EOT
}

resource "docker_volume" "home_volume" {
  name = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "postgres_volume" {
  name = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-${data.coder_workspace.me.id}-postgres"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_network" "workspace" {
  name  = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-network"
  count = data.coder_workspace.me.start_count
}

resource "docker_container" "pg" {
  count        = data.coder_workspace.me.start_count
  name         = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-pg"
  image        = "postgres:${data.coder_parameter.postgres_version.value}"
  hostname     = "postgres"
  network_mode = docker_network.workspace[count.index].name
  env = [
    "POSTGRES_ROOT_PASSWORD=embold",
    "POSTGRES_DB=${local.postgres_db}",
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
  name = "emboldcreative/ruby:rbenv${data.coder_parameter.ruby_version.value}-ubuntu${data.coder_parameter.ubuntu_version.value}"
}

resource "docker_image" "ruby" {
  name          = data.docker_registry_image.ruby.name
  pull_triggers = [data.docker_registry_image.ruby.sha256_digest]
  keep_locally  = true
  # build {
  #   context = "./build"
  #   build_arg = {
  #     RUBY_VERSION : data.coder_parameter.ruby_version.value
  #     UBUNTU_VERSION : data.coder_parameter.ubuntu_version.value
  #   }
  # }
  # triggers = {
  #   dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  # }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.ruby.name
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "BUNDLE_APP_CONFIG=${local.gem_home}",
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "GEM_HOME=${local.gem_home}",
    "PATH=$PATH:${local.gem_home}/bin",
    "PGDATABASE=${local.postgres_db}",
    "PGHOST=postgres",
    "PGPASSWORD=embold",
    "PGUSER=embold",
    "RUBY_VERSION=${data.coder_parameter.ruby_version.value}"
  ]
  # host {
  #   host = "host.docker.internal"
  #   ip   = "host-gateway"
  # }
  volumes {
    container_path = "/home/embold"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  network_mode = docker_network.workspace[count.index].name
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
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
    value = local.devurl
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
  agent_name     = data.coder_workspace.me.name
  folder         = "/home/embold/code/${local.app}"
  jetbrains_ides = ["RM"]
}
