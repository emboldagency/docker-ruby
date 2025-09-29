# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.11.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6.2"
    }
  }
}

# =============================================================================
# PROVIDERS
# =============================================================================
provider "coder" {}

provider "docker" {
  registry_auth {
    address  = "registry-1.docker.io"
    username = "emboldcreative"
    password = var.DOCKER_REGISTRY_PASS
  }
}

# =============================================================================
# VARIABLES
# =============================================================================
variable "DOCKER_REGISTRY_PASS" {
  sensitive = true
}

# =============================================================================
# DATA SOURCES - CODER CONTEXT
# =============================================================================
data "coder_external_auth" "github" { id = "github" }
data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# PARAMETERS - INFRASTRUCTURE
# =============================================================================
data "coder_parameter" "ruby_version" {
  name        = "Ruby Version"
  description = "Which version of Ruby? Must match a emboldcreative/ruby image tag on DockerHub"
  icon        = "/icon/ruby.png"
  type        = "string"
  default     = "3.4.6"
  mutable     = true
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

data "coder_parameter" "postgres_version" {
  name        = "Postgres Version"
  description = "What version of Postgres? Must match an official postgres image tag on DockerHub. NOTE: Changing this without destroying the PG volume will cause the PG container to fail to start"
  icon        = "/icon/database.svg"
  type        = "string"
  default     = "15"
  mutable     = true
}

# =============================================================================
# PARAMETERS - APPLICATION
# =============================================================================
data "coder_parameter" "git_clone_url" {
  name        = "Git Clone URL"
  description = "The HTTPS version of the Git Repo to clone."
  type        = "string"
  default     = ""
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

data "coder_parameter" "rails_master_key" {
  name        = "Rails Master Key"
  description = "Enter the rails master key to use for encrypted credentials. This will set the RAILS_MASTER_KEY environment variable."
  icon        = "/emojis/1f511.png"
  type        = "string"
  default     = "3.4.6"
  mutable     = true
}

# =============================================================================
# PARAMETERS - WORKSPACE PREFERENCES
# =============================================================================
data "coder_parameter" "timezone" {
  name        = "Timezone"
  description = "Set the container timezone for the workspace."
  type        = "string"
  default     = "America/New_York"
  mutable     = true
  option {
    name  = "UTC"
    value = "UTC"
  }
  option {
    name  = "America/New_York (Eastern)"
    value = "America/New_York"
  }
  option {
    name  = "America/Los_Angeles (Pacific)"
    value = "America/Los_Angeles"
  }
}

data "coder_parameter" "vscode_web_theme" {
  name        = "VS Code Web Theme"
  description = "Which theme do you prefer for VS Code Web?"
  icon        = "/icon/code.svg"
  type        = "string"
  default     = "Default Dark Modern"
  mutable     = true
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
  template_version      = "1.4.0"
  ubuntu_version        = data.coder_parameter.ubuntu_version.value
  timezone              = coalesce(data.coder_parameter.timezone.value, "UTC")
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
    TZ                     = local.timezone
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
  # TODO: Re-enable these at some point
  # metadata {
  #   display_name = "Home Volume Size"
  #   key          = "home_volume_size"
  #   script       = "du -BG --apparent-size /home/embold | tail -1 | awk '{print $1}'"
  #   interval     = 300
  #   timeout      = 30
  #   order        = 3
  # }
  # metadata {
  #   display_name = "Database Size"
  #   key          = "postgres_volume_size"
  #   script       = "psql -U embold -d labspend -c \"SELECT pg_size_pretty(pg_database_size('labspend'));\" -t | xargs"
  #   interval     = 300
  #   timeout      = 30
  #   order        = 4
  # }
  # startup_script = <<-EOT
  #       set -e
  #       /bin/bash /coder/scripts/configure
  #   EOT
}

resource "coder_agent" "postgres" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"
  env = {
    TZ                   = local.timezone
  }
}

resource "coder_agent" "adminer" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"
  env = {
    TZ                   = local.timezone
  }
  # TODO: Re-enable these at some point
  # metadata {
  #   display_name = "Adminer CPU"
  #   key          = "cpu"
  #   script       = "coder stat cpu"
  #   interval     = 30
  #   timeout      = 1
  #   order        = 1
  # }
  # metadata {
  #   display_name = "Adminer Memory"
  #   key          = "mem"
  #   script       = "coder stat mem --prefix 'Gi' | sed 's/ //;s/iB//'"
  #   interval     = 30
  #   timeout      = 1
  #   order        = 2
  # }
}

resource "coder_agent" "mailpit" {
  arch                    = data.coder_provisioner.me.arch
  os                      = "linux"
  startup_script_behavior = "blocking"
  env = {
    APP                    = "mailpit"
    TZ                     = local.timezone
  }
  # TODO: Re-enable these at some point
  # metadata {
  #   display_name = "Mailpit CPU"
  #   key          = "cpu"
  #   script       = "coder stat cpu"
  #   interval     = 30
  #   timeout      = 1
  #   order        = 1
  # }
  # metadata {
  #   display_name = "Mailpit Memory"
  #   key          = "mem"
  #   script       = "coder stat mem --prefix 'Gi' | sed 's/ //;s/iB//'"
  #   interval     = 30
  #   timeout      = 1
  #   order        = 2
  # }
  # metadata {
  #   display_name = "Home Volume Size"
  #   key          = "home_volume_size"
  #   script       = "du -BG --apparent-size /home/embold | tail -1 | awk '{print $1}'"
  #   interval     = 300
  #   timeout      = 30
  #   order        = 3
  # }
  # metadata {
  #   display_name = "Database Size"
  #   key          = "postgres_volume_size"
  #   script       = "psql -U embold -d labspend -c \"SELECT pg_size_pretty(pg_database_size('labspend'));\" -t | xargs"
  #   interval     = 300
  #   timeout      = 30
  #   order        = 4
  # }
  # startup_script = <<-EOT
  #       set -e
  #       exec mailpit --http-bind=127.0.0.1:8025
  #   EOT
}

# =============================================================================
# CODER SCRIPTS & MODULES
# =============================================================================
# TODO: Convert this to a module
resource "coder_script" "ssh_github_keys" {
  agent_id     = coder_agent.main.id
  display_name = "SSH & GitHub Keys"
  run_on_start = true
  icon         = "icons/git.svg"
  script       = <<-EOT
    set -e

    # --- Ensure .ssh and known_hosts exist ---
    mkdir -p /home/embold/.ssh
    touch /home/embold/.ssh/known_hosts

    # --- Always (re)add GitHub SSH host keys (idempotent) ---
    grep -v '^github.com ' /home/embold/.ssh/known_hosts > /home/embold/.ssh/known_hosts.tmp || true
    if curl -L https://api.github.com/meta | jq -r '.ssh_keys | .[]' | sed -e 's/^/github.com /' >>/home/embold/.ssh/known_hosts.tmp; then
      mv /home/embold/.ssh/known_hosts.tmp /home/embold/.ssh/known_hosts
    else
      echo "Warning: Could not update GitHub SSH keys, continuing..."
      rm -f /home/embold/.ssh/known_hosts.tmp
    fi

    # --- Add host keys for all our relevant hostnames and IPs for ports 2022 and 3022 ---
    # coder.ssh.embold.net (8.42.149.40:2022)
    keyscan_coder="$(ssh-keyscan -p 2022 -t ed25519 coder.ssh.embold.net 2>/dev/null)"
    if [ -n "$keyscan_coder" ]; then
      echo "$keyscan_coder" >> /home/embold/.ssh/known_hosts
      echo "$keyscan_coder" | sed 's/coder\.ssh\.embold\.net/8.42.149.40/' >> /home/embold/.ssh/known_hosts
    fi

    # maintenance.ssh.embold.net (8.42.149.40:3022)
    keyscan_maint="$(ssh-keyscan -p 3022 -t ed25519 maintenance.ssh.embold.net 2>/dev/null)"
    if [ -n "$keyscan_maint" ]; then
      echo "$keyscan_maint" >> /home/embold/.ssh/known_hosts
      echo "$keyscan_maint" | sed 's/maintenance\.ssh\.embold\.net/8.42.149.40/' >> /home/embold/.ssh/known_hosts
    fi

    # staging.ssh.embold.net (8.42.149.41:22)
    keyscan_staging="$(ssh-keyscan -p 22 -t ed25519 staging.ssh.embold.net 2>/dev/null)"
    if [ -n "$keyscan_staging" ]; then
      echo "$keyscan_staging" >> /home/embold/.ssh/known_hosts
      echo "$keyscan_staging" | sed 's/staging\.ssh\.embold\.net/8.42.149.41/' >> /home/embold/.ssh/known_hosts
    fi

    # --- Only fetch and set up coder signing keys if not already present ---
    if [ ! -f /home/embold/.ssh/coder ]; then
      mkdir -p /home/embold/.config/coder-api
      if curl --request GET \
        --url "${data.coder_workspace.me.access_url}/api/v2/workspaceagents/me/gitsshkey" \
        --header "Coder-Session-Token: $CODER_AGENT_TOKEN" \
        -o /home/embold/.config/coder-api/gitsshkey.json; then

        jq -r '.public_key' /home/embold/.config/coder-api/gitsshkey.json | tr -d "\n" >/home/embold/.ssh/coder.pub || true
        echo -n " coder:$CODER_USERNAME@embold.dev" >>/home/embold/.ssh/coder.pub
        jq -r '.private_key' /home/embold/.config/coder-api/gitsshkey.json >/home/embold/.ssh/coder || true

        # Symlink to standard SSH key filenames based on key type
        key_type=$(awk '{print $1}' /home/embold/.ssh/coder.pub)
        case "$key_type" in
          ssh-ed25519)
            ln -sf /home/embold/.ssh/coder /home/embold/.ssh/id_ed25519
            ln -sf /home/embold/.ssh/coder.pub /home/embold/.ssh/id_ed25519.pub
            ;;
          ssh-rsa)
            ln -sf /home/embold/.ssh/coder /home/embold/.ssh/id_rsa
            ln -sf /home/embold/.ssh/coder.pub /home/embold/.ssh/id_rsa.pub
            ;;
          ecdsa-sha2-nistp256)
            ln -sf /home/embold/.ssh/coder /home/embold/.ssh/id_ecdsa
            ln -sf /home/embold/.ssh/coder.pub /home/embold/.ssh/id_ecdsa.pub
            ;;
        esac

        # --- Commit signing setup ---
        mkdir -p /home/embold/.ssh/git-commit-signing
        cp /home/embold/.ssh/coder.pub /home/embold/.ssh/git-commit-signing || true

        chmod 0700 "/home/embold/.ssh" "/home/embold/.ssh/git-commit-signing" || true
        chmod 600 /home/embold/.ssh/* /home/embold/.ssh/git-commit-signing/* /home/embold/.config/coder-api/gitsshkey.json || true

        git config --global gpg.format ssh || true
        git config --global commit.gpgsign true || true
        git config --global user.signingkey ~/.ssh/coder || true
      else
        echo "Warning: Could not fetch coder signing keys, continuing..."
      fi
    else
      # If coder key exists, just fix permissions
      sudo chmod 0700 "/home/embold/.ssh"
      sudo chmod 600 /home/embold/.ssh/*
    fi

    exit 0
  EOT
}

# TODO: Convert this to a module
# resource "coder_script" "homebrew" {
#   agent_id     = coder_agent.main.id
#   display_name = "Homebrew (Linuxbrew)"
#   run_on_start = true
#   icon         = "https://brew.sh/assets/img/homebrew-256x256.png"
#   script       = <<-EOT
#     set -e

#     # --- Ensure Homebrew is available in this shell ---
#     if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
#       eval "$('/home/linuxbrew/.linuxbrew/bin/brew' shellenv)"
#     elif command -v brew >/dev/null 2>&1; then
#       eval "$($(command -v brew) shellenv)"
#     else
#       NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#       if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
#         eval "$('/home/linuxbrew/.linuxbrew/bin/brew' shellenv)"
#       else
#         echo "Homebrew install failed or brew not found. Exiting."
#         exit 1
#       fi
#     fi

#     # --- Add brew to PATH for current and future sessions (.profile) ---
#     if ! grep -q 'brew shellenv' /home/embold/.profile 2>/dev/null; then
#       echo 'eval "$(/home/linuxbrew/.linuxbrew/Homebrew/bin/brew shellenv)"' >> /home/embold/.profile
#     fi

#     # --- Add brew to PATH for current and future zsh sessions (.zshrc) ---
#     if ! grep -q 'brew shellenv' /home/embold/.zshrc 2>/dev/null; then
#       echo 'eval "$(/home/linuxbrew/.linuxbrew/Homebrew/bin/brew shellenv)"' >> /home/embold/.zshrc
#     fi

#     # --- Install required packages if not already installed ---
#     # for pkg in gcc caddy mailpit micro zoxide; do
#     for pkg in gcc caddy micro zoxide; do
#       if ! brew list "$pkg" >/dev/null 2>&1; then
#         brew install "$pkg"
#       else
#         echo "$pkg already installed, skipping."
#       fi
#     done

#     echo "Homebrew and required packages installed."
#     exit 0
#   EOT
# }

module "dotfiles" {
  agent_id             = coder_agent.main.id
  count                = data.coder_workspace.me.start_count
  source               = "registry.coder.com/coder/dotfiles/coder"
  version              = "1.2.1"
  default_dotfiles_uri = ""
}

module "code-server" {
  display_name = "VS Code Web"
  source       = "registry.coder.com/coder/code-server/coder"
  agent_id     = coder_agent.main.id
  folder       = "/home/embold/code/${local.app}"
  extensions   = []
  settings = {
    "workbench.colorTheme" : data.coder_parameter.vscode_web_theme.value
  }
}

module "git-clone" {
  count       = data.coder_workspace.me.start_count
  source      = "registry.coder.com/coder/git-clone/coder"
  version     = "1.1.0"
  agent_id    = coder_agent.main.id
  url         = data.coder_parameter.git_clone_url.value
  folder_name = local.app
  base_dir    = "/home/embold/code"
}

# module "git-commit-signing" {
#   count    = data.coder_workspace.me.start_count
#   source   = "git::https://github.com/emboldagency/coder-registry.git//registry/embold/modules/git-commit-signing?ref=release/embold/git-commit-signing/v1.0.1"
#   agent_id = coder_agent.main.id
# }

module "git-config" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}


# module "ssh_github_keys" {
#   source       = "../coder-module-ssh-github-keys"
#   count        = data.coder_workspace.me.start_count
#   agent_id     = coder_agent.main.id
#   access_url   = data.coder_workspace.me.access_url
#   run_on_start = true
# }


module "jetbrains" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/jetbrains/coder"
  version  = "1.0.0"
  agent_id = coder_agent.main.id
  folder   = "/home/embold/code/${local.app}"
  default  = ["RM"]
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
    label = "coder.username"
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
    label = "coder.workspace_name_at_creation"
    value = local.workspace_name
  }
}

resource "docker_volume" "postgres_volume" {
  name = "${local.resource_name_base}-postgres"
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
  name = "${local.resource_name_base}-mailpit"
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

# Persistent Homebrew (Linuxbrew) volume
# resource "docker_volume" "linuxbrew_volume" {
#   name = "${local.resource_name_base}-linuxbrew"
#   lifecycle {
#     ignore_changes = all
#   }
#   # Add labels in Docker to keep track of orphan resources.
#   labels {
#     label = "coder.owner"
#     value = local.user_username
#   }
#   labels {
#     label = "coder.owner_id"
#     value = local.user_id
#   }
#   labels {
#     label = "coder.workspace_id"
#     value = local.workspace_id
#   }
#   # This field becomes outdated if the workspace is renamed but can
#   # be useful for debugging or cleaning out dangling volumes.
#   labels {
#     label = "coder.workspace_name_at_creation"
#     value = local.workspace_name
#   }
# }

# =============================================================================
# DOCKER IMAGES
# =============================================================================
data "docker_registry_image" "ruby" {
  name = "emboldcreative/ruby:${local.ruby_version}-ubuntu${local.ubuntu_version}-release${local.template_version}"
}

resource "docker_image" "ruby" {
  name          = data.docker_registry_image.ruby.name
  pull_triggers = [data.docker_registry_image.ruby.sha256_digest]
  keep_locally  = true
}

# resource "docker_network" "workspace" {
#   name  = "${local.resource_name_base}-network"
#   count = data.coder_workspace.me.start_count
# }

data "docker_registry_image" "adminer" {
  name = "emboldcreative/adminer-coder:latest"
}

resource "docker_image" "adminer" {
  name          = data.docker_registry_image.adminer.name
  pull_triggers = [data.docker_registry_image.adminer.sha256_digest]
  keep_locally  = true
}

data "docker_registry_image" "mailpit" {
  name = "emboldcreative/mailpit-coder:latest"
}

resource "docker_image" "mailpit" {
  name          = data.docker_registry_image.mailpit.name
  pull_triggers = [data.docker_registry_image.mailpit.sha256_digest]
  keep_locally  = true
}

# =============================================================================
# DOCKER CONTAINERS
# =============================================================================
resource "docker_container" "postgres" {
  count        = data.coder_workspace.me.start_count
  name         = "${local.resource_name_base}-postgres"
  image        = "postgres:${local.postgres_version}"
  hostname     = "postgres"
  entrypoint = ["sh", "-c", replace(coder_agent.postgres.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
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

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = docker_image.ruby.name
  name       = local.resource_name_base
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
  # volumes {
  #   container_path = "/home/linuxbrew"
  #   volume_name    = docker_volume.linuxbrew_volume.name
  #   read_only      = false
  # }
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

# resource "coder_app" "web_app" {
#   agent_id     = coder_agent.main.id
#   display_name = "Web App"
#   slug         = "webapp"
#   icon         = "/emojis/1f310.png"
#   url          = "http://localhost:3000"
#   subdomain    = true
#   share        = "public"
#   order        = 1
#   # healthcheck {
#   #   url       = "http://localhost:443"
#   #   interval  = 5
#   #   threshold = 6
#   # }
# }

# resource "docker_image" "mailpit" {
#   name = "axllent/mailpit:latest"
# }

# resource "docker_volume" "mailpit_volume" {
#   name = "${local.resource_name_base}-mailpit"
#   lifecycle {
#     ignore_changes = all
#   }
#   # Add labels in Docker to keep track of orphan resources.
#   labels {
#     label = "coder.owner"
#     value = local.user_username
#   }
#   labels {
#     label = "coder.owner_id"
#     value = local.user_id
#   }
#   labels {
#     label = "coder.workspace_id"
#     value = local.workspace_id
#   }
#   # This field becomes outdated if the workspace is renamed but can
#   # be useful for debugging or cleaning out dangling volumes.
#   labels {
#     label = "coder.workspace_name_at_creation"
#     value = local.workspace_name
#   }
# }

resource "docker_container" "adminer" {
  count        = data.coder_workspace.me.start_count
  network_mode = docker_network.workspace[count.index].name
  name         = "${local.resource_name_base}-adminer"
  image        = docker_image.adminer.name
  hostname     = "adminer"
  entrypoint = ["sh", "-c", replace(coder_agent.adminer.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.adminer.token}",
    "ADMINER_DEFAULT_DB=${local.db_name}",
    "ADMINER_DEFAULT_DRIVER=pgsql",
    "ADMINER_DEFAULT_PASSWORD=embold",
    "ADMINER_DEFAULT_SERVER=postgres",
    "ADMINER_DEFAULT_USERNAME=embold",
    "ADMINER_DESIGN=pappu687",
    "ADMINER_PLUGINS=adminer-auto-login",
  ]
}

resource "docker_container" "mailpit" {
  count        = data.coder_workspace.me.start_count
  name         = "${local.resource_name_base}-mailpit"
  image        = docker_image.mailpit.name
  hostname     = "mailpit"
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  network_mode = docker_network.workspace[count.index].name
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.mailpit.token}",
    "MP_API_PORT=8026",
    "MP_DATABASE=/data/mailpit.db",
    "MP_MAX_AGE=30d",
    "MP_MAX_MESSAGES=5000",
    "MP_SMTP_BIND_ADDR=0.0.0.0:1025",
    "MU_UI_BIND_ADDR=0.0.0.0:8025",
  ]
  volumes {
    container_path = "/data"
    volume_name    = docker_volume.mailpit_volume.name
    read_only      = false
  }
}

# =============================================================================
# CODER APPS & UI
# =============================================================================
resource "coder_app" "web_app" {
  agent_id     = coder_agent.main.id
  display_name = "Web App"
  slug         = "webapp"
  icon         = "/emojis/1f310.png"
  url          = "http://localhost:3000"
  subdomain    = true
  share        = "public"
  order        = 1
}

resource "coder_app" "adminer" {
  agent_id     = coder_agent.adminer.id
  slug         = "adminer"
  display_name = "Adminer"
  url          = "http://localhost:8080"
  icon         = "http://www.adminer.org/favicon.ico"
  share        = "authenticated"
  order        = 2
  healthcheck {
    url       = "http://localhost:8080"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "mailpit" {
  agent_id     = coder_agent.mailpit.id
  slug         = "mailpit"
  display_name = "Mailpit"
  url          = "http://localhost:8025"
  share        = "authenticated"
  subdomain    = true
  icon         = "https://mailpit.axllent.org/images/mailpit.svg"
  healthcheck {
    url       = "http://localhost:8025"
    interval  = 5
    threshold = 6
  }
}

# =============================================================================
# METADATA & MONITORING
# =============================================================================
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
  item {
    key   = "Template"
    value = local.template_version
  }
}

# resource "coder_script" "caddy" {
#   agent_id     = coder_agent.main.id
#   display_name = "Caddy Proxies"
#   icon         = "https://caddyserver.com/resources/images/favicon.png"
#   run_on_start = true
#   script       = <<-EOT
#     set -e

#     echo "Waiting for Caddy to be installed..."
#     attempts=0
#     max_attempts=60
#     while true; do
#       if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
#         eval "$('/home/linuxbrew/.linuxbrew/bin/brew' shellenv)"
#       fi
#       if command -v caddy >/dev/null 2>&1 || [ -x /home/linuxbrew/.linuxbrew/bin/caddy ]; then
#         echo "Caddy found!"

#         # --- Start Caddy reverse proxies ---
#         echo "Starting Caddy reverse proxy for Adminer..."
#         mkdir -p /home/embold/.local/tmp/caddy
#         caddy reverse-proxy --from :8080 --to http://adminer:8080 > /home/embold/.local/tmp/caddy/caddy-adminer.log 2>&1 &
#         echo "Caddy is running, reverse proxying Adminer at http://localhost:8080"

#         echo "Starting Caddy reverse proxy for Mailpit..."
#         caddy reverse-proxy --from :8025 --to http://mailpit:8025 > /home/embold/.local/tmp/caddy/caddy-mailpit.log 2>&1 &
#         echo "Caddy is running, reverse proxying Mailpit at http://localhost:8025"

#         break
#       fi
#       attempts=$((attempts+1))
#       if [ "$attempts" -ge "$max_attempts" ]; then
#         echo "Timeout: Caddy not found after $((max_attempts*2)) seconds. Please check Homebrew install."
#         exit 1
#       fi
#       sleep 2
#     done
#   EOT
# }