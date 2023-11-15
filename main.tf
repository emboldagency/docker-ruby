terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12.1"
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
}

data "coder_provisioner" "me" {
}

data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_timeout  = 180
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
    "CODER_USERNAME"       = data.coder_workspace.me.owner
    "CODER_WORKSPACE_PORT" = 3000
    "CODER_WORKSPACE_NAME" = data.coder_workspace.me.name
    "APP"                  = data.coder_workspace.me.name
    "GIT_AUTHOR_NAME"      = data.coder_workspace.me.owner
    "GIT_COMMITTER_NAME"   = data.coder_workspace.me.owner
    "GIT_AUTHOR_EMAIL"     = data.coder_workspace.me.owner_email
    "GIT_COMMITTER_EMAIL"  = data.coder_workspace.me.owner_email
    "PGHOST"               = "postgres"
  }
    startup_script = <<-EOT
        set -e
        /bin/bash /coder/configure
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

resource "docker_network" "workspace_network" {
  name   = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-network"
  driver = "bridge"
}

resource "docker_container" "pg" {
    name         = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-pg"
    image        = "postgres:15"
    restart      = "unless-stopped"
    hostname     = "postgres"
    network_mode = docker_network.workspace_network.name
    env = [
        "POSTGRES_ROOT_PASSWORD=embold",
        "POSTGRES_DB=${data.coder_workspace.me.name}",
        "POSTGRES_USER=embold",
        "POSTGRES_PASSWORD=embold",
    ]
    volumes {
        container_path = "/var/lib/postgresql/data"
        volume_name    = docker_volume.postgres_volume.name
        read_only      = false
    }
}

resource "docker_image" "ruby302" {
    name          = "emboldcreative/ruby:3.0.2-ubuntu22.04"
    build {
        context = "./build"
    }
    keep_locally = true
}

resource "docker_container" "workspace" {
    count = data.coder_workspace.me.start_count
    image = docker_image.ruby302.name
    # Uses lower() to avoid Docker restriction on container names.
    name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    # Hostname makes the shell more user friendly: coder@my-workspace:~$
    hostname = data.coder_workspace.me.name
    # Use the docker gateway if the access URL is 127.0.0.1
    entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
    env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
    host {
        host = "host.docker.internal"
        ip   = "host-gateway"
    }
    volumes {
        container_path = "/home/embold"
        volume_name    = docker_volume.home_volume.name
        read_only      = false
    }
    network_mode = docker_network.workspace_network.name
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

resource "coder_app" "ruby_app" {
    agent_id  = coder_agent.main.id
    slug      = "webapp"
    icon      = "/icon/ruby.png"
    url       = "http://localhost:3000"
    subdomain = true
    share     = "public"
    healthcheck {
        url       = "http://localhost:3000/up"
        interval  = 10
        threshold = 30
    }
}

resource "coder_metadata" "container_info" {
    count       = data.coder_workspace.me.start_count
    resource_id = docker_container.workspace[0].id

    item {
        key   = "image"
        value = docker_image.ruby302.name
    }
    item {
        key   = "devurl"
        value = "https://webapp--main--${data.coder_workspace.me.name}--${data.coder_workspace.me.owner}.embold.app/"
    }
}

module "code-server" {
    display_name = "VS Code Web"
    source = "https://registry.coder.com/modules/code-server"
    agent_id = coder_agent.main.id
    folder         = "/home/embold/code/${data.coder_workspace.me.name}"
    extensions = []
    settings = {
        "workbench.colorTheme": "Default Dark Modern"
    }
}

module "jetbrains_gateway" {
    source         = "https://registry.coder.com/modules/jetbrains-gateway"
    agent_id       = coder_agent.main.id
    agent_name     = data.coder_workspace.me.name
    folder         = "/home/embold/code/${data.coder_workspace.me.name}"
    jetbrains_ides = ["RM"]
}

module "git-commit-signing" {
    source = "https://registry.coder.com/modules/git-commit-signing"
    agent_id = coder_agent.main.id
}