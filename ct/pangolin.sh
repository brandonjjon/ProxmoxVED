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

# Collect Pangolin configuration before container creation using whiptail
msg_info "Pangolin Configuration"

PANGOLIN_BASE_DOMAIN=$(whiptail --inputbox \
  "Enter your base domain name or IP address.\n\nExamples:\n  - example.com\n  - 10.10.0.180\n  - pangolin.mydomain.com" \
  12 70 \
  --title "Base Domain" 3>&1 1>&2 2>&3)

if [[ -z "$PANGOLIN_BASE_DOMAIN" ]]; then
  msg_error "Base domain is required. Exiting."
  exit 1
fi

PANGOLIN_DASHBOARD_DOMAIN=$(whiptail --inputbox \
  "Enter your dashboard domain name or IP address.\n\nThis is where you'll access the Pangolin web interface.\n\nPress Enter to use: ${PANGOLIN_BASE_DOMAIN}" \
  12 70 \
  "${PANGOLIN_BASE_DOMAIN}" \
  --title "Dashboard Domain" 3>&1 1>&2 2>&3)

PANGOLIN_DASHBOARD_DOMAIN="${PANGOLIN_DASHBOARD_DOMAIN:-$PANGOLIN_BASE_DOMAIN}"

PANGOLIN_EMAIL=$(whiptail --inputbox \
  "Enter your email address for Let's Encrypt SSL certificates.\n\nIf using an IP address, you can use a placeholder email.\n\nPress Enter to use: admin@${PANGOLIN_BASE_DOMAIN}" \
  12 70 \
  "admin@${PANGOLIN_BASE_DOMAIN}" \
  --title "Let's Encrypt Email" 3>&1 1>&2 2>&3)

PANGOLIN_EMAIL="${PANGOLIN_EMAIL:-admin@${PANGOLIN_BASE_DOMAIN}}"

# Show configuration summary
whiptail --title "Configuration Summary" --msgbox \
"Pangolin will be configured with:

Base Domain: ${PANGOLIN_BASE_DOMAIN}
Dashboard Domain: ${PANGOLIN_DASHBOARD_DOMAIN}
Email: ${PANGOLIN_EMAIL}

Press OK to continue with installation." \
14 70

# Export variables to pass to install script
export PANGOLIN_BASE_DOMAIN
export PANGOLIN_DASHBOARD_DOMAIN
export PANGOLIN_EMAIL

msg_ok "Configuration Collected"

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
