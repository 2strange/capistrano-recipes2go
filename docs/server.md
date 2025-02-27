# 🚀 Capistrano Server Setup for Debian 12 / Ubuntu 24.04

This Capistrano task automates the setup of a Debian 12 or Ubuntu 24.04 server with essential dependencies, including **Ruby (RVM)**, **Node.js (NVM)**, **Nginx**, **PostgreSQL**, **Redis**, **Thin**, and **Certbot (Let's Encrypt)**.

## 📜 Overview

This script performs the following steps:

1. Updates system packages
2. Creates a deploy user (optional)
3. Installs required dependencies:
   - ImageMagick
   - PostgreSQL
   - Nginx
   - Redis
   - Thin (optional)
   - Certbot (for HTTPS certificates)
4. Installs Ruby using RVM
5. Installs Node.js using NVM
6. Configures UFW firewall rules
7. Generates an SSH key (if missing) for GitLab deployment

## ⚙️ Configuration

The script is **highly configurable** using Capistrano variables.

```ruby
set :srvr_user,                 "deploy"    # Deployment user
set :srvr_create_user,          false       # Create deploy user if missing

set :srvr_install_rvm,          true        # Install RVM and Ruby
set :srvr_rvm_ruby_version,     "3.3.5"     # Ruby version

set :srvr_install_nvm,          true        # Install NVM
set :srvr_nvm_version,          "v0.39.7"   # NVM version
set :srvr_nvm_node_version,     "23"        # Node.js version

set :srvr_install_nginx,        true        # Install Nginx
set :srvr_install_postgres,     true        # Install PostgreSQL
set :srvr_install_certbot,      true        # Install Certbot (SSL)
set :srvr_install_redis,        true        # Install Redis
set :srvr_install_thin,         false       # Install Thin (set to true if needed)

set :srvr_enable_firewall,      true        # Enable UFW firewall
set :srvr_ufw_additional_ports, ["2224", "8080"] # Open additional firewall ports
```

## 🚀 Running the Setup

In Capfile:
```ruby

# Capfile .. best only the server script for the setup .. especially rvm would lead to issues before setup is done
require 'capistrano/recipes2go/server'

```

Run the setup task using:
```sh

cap production server:setup

```

---

## 🛠️ Setup Steps

### 1️⃣ System Update & Package Installation

- Updates system (`apt update && apt upgrade`)
- Installs essential build tools (`build-essential`, `curl`, `git`)

### 2️⃣ Create Deploy User (Optional)

If `set :srvr_create_user, true`:
- Creates the deploy user (`deploy`)
- Grants sudo privileges
- Configures passwordless sudo access

### 3️⃣ Install Services

- **PostgreSQL**: Installs and enables `postgresql` service
- **Nginx**: Installs and enables `nginx`
- **Redis**: Installs and enables `redis-server`
- **Thin**: Installs Thin and ensures the correct config directory

### 4️⃣ Install RVM & Ruby

If `set :srvr_install_rvm, true`:
- Installs **RVM** (Ruby Version Manager)
- Installs Ruby (`3.3.5` or another version)

### 5️⃣ Install NVM & Node.js

If `set :srvr_install_nvm, true`:
- Installs **NVM** (Node Version Manager)
- Installs Node.js (`v23` or another specified version)
- Moves NVM initialization **to the top** of `.bashrc` to ensure it's always available

### 6️⃣ Configure Firewall (UFW)

If `set :srvr_enable_firewall, true`:
- Ensures UFW is installed
- Allows **OpenSSH**, **HTTP (80)**, and **HTTPS (443)**
- Allows additional ports (`2224, 8080` if configured)
- Enables UFW

### 7️⃣ Generate SSH Key for GitLab (If Missing)

If `~/.ssh/id_rsa.pub` doesn't exist:
- Generates a new **SSH key**
- Displays it for manual addition to **GitLab SSH Keys**

---

## 🛠️ Troubleshooting

### ❌ `nvm: command not found`
- Ensure NVM is installed and sourced at the **top** of `.bashrc`
- Run:
  ```sh
  source ~/.bashrc
  nvm --version
  ```

### ❌ `Permission denied` for `/etc/profile.d/nvm.sh`
- Ensure your user has **sudo** access
- Manually install NVM:
  ```sh
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  ```

### ❌ `Thin config directory issue`
- If Thin’s config is missing:
  ```sh
  ls -d /etc/thin*
  ```

---

## 🔗 Useful Resources

- [Capistrano Docs](https://capistranorb.com/documentation/getting-started/)
- [RVM Installation](https://rvm.io/)
- [NVM Installation](https://github.com/nvm-sh/nvm)
- [UFW Firewall Guide](https://wiki.ubuntu.com/UncomplicatedFirewall)

---

### ✅ **Done!** 🎉  
Your server is now fully configured and ready to deploy 🚀

---

Let me know if you want any changes! 😊