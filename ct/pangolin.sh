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
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Complete setup using your configured domain:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://your-domain.com/auth/initial-setup${CL}"
echo -e "${INFO}${YW} Credentials saved to:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}~/pangolin.creds${CL}"
