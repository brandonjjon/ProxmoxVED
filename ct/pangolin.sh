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

# Collect Pangolin configuration before container creation
msg_info "Pangolin Configuration Required"
echo -e "${YW}Pangolin requires a domain name for proper operation.${CL}\n"

# Base Domain
while true; do
  echo -e "${BL}Enter your root domain without subdomains.${CL}"
  echo -e "${DGN}Example: example.com${CL}"
  read -r -p "Base Domain: " PANGOLIN_BASE_DOMAIN

  if [[ -z "$PANGOLIN_BASE_DOMAIN" ]]; then
    echo -e "${RD}Base domain is required. Please try again.${CL}\n"
  else
    break
  fi
done

# Dashboard Domain
echo -e "\n${BL}Enter your dashboard domain.${CL}"
echo -e "${DGN}This is where you'll access the Pangolin web interface.${CL}"
echo -e "${DGN}Press Enter to use: pangolin.${PANGOLIN_BASE_DOMAIN}${CL}"
read -r -p "Dashboard Domain [pangolin.${PANGOLIN_BASE_DOMAIN}]: " PANGOLIN_DASHBOARD_DOMAIN
PANGOLIN_DASHBOARD_DOMAIN="${PANGOLIN_DASHBOARD_DOMAIN:-pangolin.${PANGOLIN_BASE_DOMAIN}}"

# Email
while true; do
  echo -e "\n${BL}Enter your email address for Let's Encrypt SSL certificates and admin login.${CL}"
  read -r -p "Email: " PANGOLIN_EMAIL

  if [[ -z "$PANGOLIN_EMAIL" ]]; then
    echo -e "${RD}Email is required. Please try again.${CL}\n"
  else
    break
  fi
done

# Show configuration summary
echo -e "\n${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}Configuration Summary:${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "  ${BL}Base Domain:${CL}      ${GN}${PANGOLIN_BASE_DOMAIN}${CL}"
echo -e "  ${BL}Dashboard Domain:${CL} ${GN}${PANGOLIN_DASHBOARD_DOMAIN}${CL}"
echo -e "  ${BL}Email:${CL}            ${GN}${PANGOLIN_EMAIL}${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}\n"

read -r -p "Continue with these settings? [Y/n]: " CONFIRM
if [[ "${CONFIRM,,}" =~ ^(n|no)$ ]]; then
  msg_error "Installation cancelled by user."
  exit 0
fi

# Export variables to pass to install script
export PANGOLIN_BASE_DOMAIN
export PANGOLIN_DASHBOARD_DOMAIN
export PANGOLIN_EMAIL

msg_ok "Configuration Collected"

build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Complete setup at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${PANGOLIN_DASHBOARD_DOMAIN}/auth/initial-setup${CL}"
echo -e "${INFO}${YW} Credentials and configuration saved to:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}~/pangolin.creds${CL}"
