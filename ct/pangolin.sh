#!/usr/bin/env bash
REPO_URL="${REPO_URL:-https://raw.githubusercontent.com/brandonjjon/ProxmoxVED/pangolin}"
# shellcheck disable=SC1090
source <(curl -fsSL "${REPO_URL}/misc/build.func")
# Copyright (c) 2021-2025 community-scripts ORG
# Author: brandonjjon
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/fosrl/pangolin

APP="Pangolin"
var_tags="${var_tags:-reverse-proxy;networking}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

# Collect Pangolin configuration before container creation
echo -e "\n${INFO} Pangolin Configuration${CL}"
echo -e "${YW}Pangolin requires a domain name for proper operation.${CL}"
echo -e "${YW}You can use a domain or IP address for testing.${CL}\n"

read -r -p "Enter your base domain (e.g., example.com or 10.10.0.180): " PANGOLIN_BASE_DOMAIN
PANGOLIN_BASE_DOMAIN="${PANGOLIN_BASE_DOMAIN:-localhost}"

read -r -p "Enter your dashboard domain (default: ${PANGOLIN_BASE_DOMAIN}): " PANGOLIN_DASHBOARD_DOMAIN
PANGOLIN_DASHBOARD_DOMAIN="${PANGOLIN_DASHBOARD_DOMAIN:-$PANGOLIN_BASE_DOMAIN}"

read -r -p "Enter your email for Let's Encrypt (or press Enter to skip): " PANGOLIN_EMAIL
PANGOLIN_EMAIL="${PANGOLIN_EMAIL:-admin@${PANGOLIN_BASE_DOMAIN}}"

# Export variables to pass to install script
export PANGOLIN_BASE_DOMAIN
export PANGOLIN_DASHBOARD_DOMAIN
export PANGOLIN_EMAIL

echo -e "\n${INFO} Configuration Summary:${CL}"
echo -e "  Base Domain: ${PANGOLIN_BASE_DOMAIN}"
echo -e "  Dashboard Domain: ${PANGOLIN_DASHBOARD_DOMAIN}"
echo -e "  Email: ${PANGOLIN_EMAIL}\n"

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/pangolin/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP}"
  cd /opt/pangolin || exit
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated ${APP}"

  msg_info "Cleaning Up"
  $STD docker image prune -af
  msg_ok "Cleaned"

  msg_ok "Update Successful"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Complete setup at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${PANGOLIN_DASHBOARD_DOMAIN}/auth/initial-setup${CL}"
echo -e "${INFO}${YW} Credentials and configuration saved to:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}~/pangolin.creds${CL}"
