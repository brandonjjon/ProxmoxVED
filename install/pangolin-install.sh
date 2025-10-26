#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: brandonjjon
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/fosrl/pangolin

# shellcheck source=/dev/null
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  ca-certificates \
  gnupg \
  openssl
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD bash <(curl -fsSL https://get.docker.com)
$STD systemctl enable --now docker
msg_ok "Installed Docker"

msg_info "Setting up Pangolin"
INSTALL_DIR="/opt/pangolin"
mkdir -p "$INSTALL_DIR"/{config/traefik,config/db,config/letsencrypt,config/logs}
cd "$INSTALL_DIR" || exit

# Use environment variables from ct script, fallback to localhost
BASE_DOMAIN="${PANGOLIN_BASE_DOMAIN:-localhost}"
DASHBOARD_DOMAIN="${PANGOLIN_DASHBOARD_DOMAIN:-localhost}"
LETSENCRYPT_EMAIL="${PANGOLIN_EMAIL:-admin@localhost}"
SERVER_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9@#%^&*()-_=+[]{}|;:,.<>?' | head -c48)

{
  echo "Pangolin Installation Complete"
  echo ""
  echo "Configuration:"
  echo "  Base Domain: ${BASE_DOMAIN}"
  echo "  Dashboard Domain: ${DASHBOARD_DOMAIN}"
  echo "  Email: ${LETSENCRYPT_EMAIL}"
  echo "  Server Secret: ${SERVER_SECRET}"
  echo ""

  if [[ "${BASE_DOMAIN}" == "localhost" ]]; then
    echo "IMPORTANT: You configured 'localhost' as the domain."
    echo "You must edit the configuration file to use your actual domain or IP:"
    echo ""
    echo "Configuration file: /opt/pangolin/config/config.yml"
    echo "Edit the config file and update:"
    echo "  - app.dashboard_url (your actual domain or IP)"
    echo "  - domains.domain1.base_domain (your actual domain or IP)"
    echo ""
    echo "After editing config, restart services:"
    echo "  cd /opt/pangolin && docker compose restart"
  else
    echo "Access Pangolin initial setup at:"
    echo "  https://${DASHBOARD_DOMAIN}/auth/initial-setup"
    echo ""
    echo "If using an IP address, you may need to accept the"
    echo "self-signed certificate in your browser."
  fi
} >>~/pangolin.creds
msg_ok "Setup Pangolin"

msg_info "Creating Docker Compose Configuration"
cat <<EOF >docker-compose.yml
services:
  pangolin:
    image: fosrl/pangolin:latest
    container_name: pangolin
    restart: unless-stopped
    volumes:
      - ./config:/app/config
      - pangolin-data:/var/certificates
      - pangolin-data:/var/dynamic
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/v1/"]
      interval: "3s"
      timeout: "3s"
      retries: 15

  gerbil:
    image: fosrl/gerbil:latest
    container_name: gerbil
    restart: unless-stopped
    depends_on:
      pangolin:
        condition: service_healthy
    command:
      - --reachableAt=http://gerbil:3004
      - --generateAndSaveKeyTo=/var/config/key
      - --remoteConfig=http://pangolin:3001/api/v1/
    volumes:
      - ./config/:/var/config
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    ports:
      - 51820:51820/udp
      - 21820:21820/udp
      - 443:443
      - 80:80

  traefik:
    image: traefik:v3.4.0
    container_name: traefik
    restart: unless-stopped
    network_mode: service:gerbil
    depends_on:
      pangolin:
        condition: service_healthy
    command:
      - --configFile=/etc/traefik/traefik_config.yml
    volumes:
      - ./config/traefik:/etc/traefik:ro
      - ./config/letsencrypt:/letsencrypt
      - pangolin-data:/var/certificates:ro
      - pangolin-data:/var/dynamic:ro

networks:
  default:
    driver: bridge
    name: pangolin

volumes:
  pangolin-data:
EOF
msg_ok "Created Docker Compose Configuration"

msg_info "Creating Pangolin Configuration"
cat <<EOF >config/config.yml
app:
  dashboard_url: "https://${DASHBOARD_DOMAIN}"
  log_level: "info"
  save_logs: false

domains:
  domain1:
    base_domain: "${BASE_DOMAIN}"
    cert_resolver: "letsencrypt"

server:
  secret: "${SERVER_SECRET}"
  external_port: 3000
  internal_port: 3001
  next_port: 3002
  internal_hostname: "pangolin"
  trust_proxy: 1
  dashboard_session_length_hours: 720
  resource_session_length_hours: 720

gerbil:
  base_endpoint: "${BASE_DOMAIN}"
  start_port: 51820

traefik:
  http_entrypoint: "web"
  https_entrypoint: "websecure"
  cert_resolver: "letsencrypt"
  prefer_wildcard_cert: false

flags:
  require_email_verification: false
  disable_signup_without_invite: true
  disable_user_create_org: true
  allow_raw_resources: true
EOF
msg_ok "Created Pangolin Configuration"

msg_info "Creating Traefik Static Configuration"
cat <<EOF >config/traefik/traefik_config.yml
api:
  insecure: true
  dashboard: true

providers:
  http:
    endpoint: "http://pangolin:3001/api/v1/traefik-config"
    pollInterval: "5s"
  file:
    filename: "/etc/traefik/dynamic_config.yml"

experimental:
  plugins:
    badger:
      moduleName: "github.com/fosrl/badger"
      version: "v1.2.0"

log:
  level: "INFO"
  format: "common"

certificatesResolvers:
  letsencrypt:
    acme:
      httpChallenge:
        entryPoint: web
      email: ${LETSENCRYPT_EMAIL}
      storage: "/letsencrypt/acme.json"
      caServer: "https://acme-v02.api.letsencrypt.org/directory"

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
    transport:
      respondingTimeouts:
        readTimeout: "30m"
    http:
      tls:
        certResolver: "letsencrypt"

serversTransport:
  insecureSkipVerify: true

ping:
    entryPoint: "web"
EOF
msg_ok "Created Traefik Static Configuration"

msg_info "Creating Traefik Dynamic Configuration"
cat <<EOF >config/traefik/dynamic_config.yml
http:
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https

  routers:
    main-app-router-redirect:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`)"
      service: next-service
      entryPoints:
        - web
      middlewares:
        - redirect-to-https

    next-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`) && !PathPrefix(\`/api/v1\`)"
      service: next-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

    api-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`) && PathPrefix(\`/api/v1\`)"
      service: api-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

    ws-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`)"
      service: api-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    next-service:
      loadBalancer:
        servers:
          - url: "http://pangolin:3002"

    api-service:
      loadBalancer:
        servers:
          - url: "http://pangolin:3000"
EOF
msg_ok "Created Traefik Dynamic Configuration"

msg_info "Setting Permissions"
chmod 600 config/letsencrypt/acme.json 2>/dev/null || touch config/letsencrypt/acme.json && chmod 600 config/letsencrypt/acme.json
chmod 600 config/config.yml
msg_ok "Set Permissions"

msg_info "Starting Pangolin Stack"
$STD docker compose up -d
msg_ok "Started Pangolin Stack"

msg_info "Waiting for Pangolin to Generate Setup Token"
SETUP_TOKEN=""
for _ in {1..30}; do
  SETUP_TOKEN=$(docker logs pangolin 2>&1 | grep -A1 "SETUP TOKEN GENERATED" | grep "Token:" | awk '{print $2}')
  if [[ -n "$SETUP_TOKEN" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "$SETUP_TOKEN" ]]; then
  msg_error "Failed to retrieve setup token from logs"
  SETUP_TOKEN="Check Docker logs: docker logs pangolin"
fi
msg_ok "Setup Token Retrieved"

# Append setup token to credentials file
{
  echo ""
  echo "=========================================="
  echo "INITIAL SETUP TOKEN (use this on first login):"
  echo "  ${SETUP_TOKEN}"
  echo "=========================================="
  echo ""
  echo "This token is required for the initial setup at:"
  echo "  https://${DASHBOARD_DOMAIN}/auth/initial-setup"
  echo ""
  echo "NOTE: The 'Server Secret' above is for session encryption,"
  echo "      NOT for the initial setup page."
} >>~/pangolin.creds

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
