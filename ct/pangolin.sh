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

# Collect Pangolin configuration using whiptail (like freepbx.sh does)
PANGOLIN_BASE_DOMAIN=$(whiptail --title "Base Domain" --inputbox "Enter your root domain without subdomains.\n\nExample: example.com" 10 70 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ] || [ -z "$PANGOLIN_BASE_DOMAIN" ]; then
    echo -e "${RD}Base domain is required. Exiting.${CL}"
    exit 1
fi

PANGOLIN_DASHBOARD_DOMAIN=$(whiptail --title "Dashboard Domain" --inputbox "Enter your dashboard domain.\n\nThis is where you'll access the Pangolin web interface.\n\nDefault: pangolin.${PANGOLIN_BASE_DOMAIN}" 12 70 "pangolin.${PANGOLIN_BASE_DOMAIN}" 3>&1 1>&2 2>&3)
PANGOLIN_DASHBOARD_DOMAIN="${PANGOLIN_DASHBOARD_DOMAIN:-pangolin.${PANGOLIN_BASE_DOMAIN}}"

PANGOLIN_EMAIL=$(whiptail --title "Let's Encrypt Email" --inputbox "Enter your email address for Let's Encrypt SSL certificates and admin login." 10 70 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ] || [ -z "$PANGOLIN_EMAIL" ]; then
    echo -e "${RD}Email is required. Exiting.${CL}"
    exit 1
fi

# Export variables to pass to install script
export PANGOLIN_BASE_DOMAIN
export PANGOLIN_DASHBOARD_DOMAIN
export PANGOLIN_EMAIL

build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Complete setup at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${PANGOLIN_DASHBOARD_DOMAIN}/auth/initial-setup${CL}"
echo -e "${INFO}${YW} Setup token and configuration saved to:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}~/pangolin.creds${CL}"
echo -e "${INFO}${YW} View setup token with:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}cat ~/pangolin.creds${CL}"
