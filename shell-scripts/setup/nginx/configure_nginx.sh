#!/bin/bash


#######################################
# Manage NGINX configuration generation
# Globals:
#   DOMAIN_NAME
#   NGINX_PORT
#   acme_challenge_server_block
#   backend_scheme
#   certs
#   default_port_directive
#   resolver_settings
#   security_headers
#   server_name
#   ssl_listen_directive
#   ssl_mode_block
# Arguments:
#  None
#######################################
configure_nginx() {
    echo "Creating NGINX configuration..."
    backend_scheme="http"
    server_name="${DOMAIN_NAME}"
    default_port_directive="listen $NGINX_PORT;"
    default_port_directive+=$'\n'
    default_port_directive+="        listen [::]:$NGINX_PORT;"
    ssl_listen_directive=""
    ssl_mode_block=""
    resolver_settings=""
    certs=""
    security_headers=""
    acme_challenge_server_block=""

    backup_existing_config
    configure_subdomain
    configure_https
    configure_acme_challenge
    write_nginx_config
}

#######################################
# Determine if a subdomain is being used and configure the server_name accordingly
# Globals:
#   DOMAIN_NAME
#   SUBDOMAIN
#   server_name
# Arguments:
#  None
#######################################
configure_subdomain() {
    if [[ $SUBDOMAIN != "www" && -n $SUBDOMAIN ]]; then
        server_name="${DOMAIN_NAME} ${SUBDOMAIN}.${DOMAIN_NAME}"
  fi
}

#######################################
# Determine if HTTPS is being used and configure the server accordingly
# Globals:
#   DNS_RESOLVER
#   NGINX_SSL_PORT
#   TIMEOUT
#   USE_LETS_ENCRYPT
#   USE_SELF_SIGNED_CERTS
#   backend_scheme
#   resolver_settings
#   ssl_listen_directive
# Arguments:
#  None
#######################################
configure_https() {
    if [[ $USE_LETS_ENCRYPT == "yes" ]] || [[ $USE_SELF_SIGNED_CERTS == "yes" ]]; then
    backend_scheme="https"
    ssl_listen_directive="listen $NGINX_SSL_PORT ssl;"
    ssl_listen_directive+=$'\n'
    ssl_listen_directive+="        listen [::]:""$NGINX_SSL_PORT ssl;"
    configure_ssl_mode
    resolver_settings="resolver ${DNS_RESOLVER} valid=300s;"
    resolver_settings+=$'\n'
    resolver_settings+="        resolver_timeout ${TIMEOUT}ms;"
    configure_certs
    configure_security_headers
  fi
}

#######################################
# Determine if TLS 1.2 and TLS 1.3 are being used and configure the server accordingly
# Globals:
#   USE_TLS12
#   USE_TLS13
#   ssl_mode_block
# Arguments:
#  None
#######################################
configure_ssl_mode() {
    if [[ $USE_TLS12 == "yes" && $USE_TLS13 == "yes" ]]; then
    ssl_mode_block=$(get_gzip)
    ssl_mode_block+=$'\n'
    ssl_mode_block+=$(get_ssl_protocol_compatibility)
    ssl_mode_block+=$'\n'
    ssl_mode_block+=$(get_ssl_additional_config)
  else
    ssl_mode_block=$(get_gzip)
    ssl_mode_block+=$'\n'
    ssl_mode_block+=$(tls_protocol_one_three_restrict)
    ssl_mode_block+=$'\n'
    ssl_mode_block+=$(get_ssl_additional_config)
  fi
}

#######################################
# Turn off gzip compression
# Globals:
#   None
# Arguments:
#  None
#######################################
get_gzip() {
        cat <<- EOF
gzip off;
EOF
}

#######################################
# description
# Arguments:
#  None
#######################################
get_ssl_protocol_compatibility() {
    cat <<- EOF
        ssl_protocols TLSv1.2 TLSv1.3;
EOF
}

#######################################
# SSL additional configuration, covering cipher suites, session cache, and other
# security-related features. This configuration is recommended for a modern secure
# Globals:
#   DH_PARAMS_PATH
#   ssl_paths
# Arguments:
#  None
#######################################
get_ssl_additional_config() {
    cat <<- EOF
        ssl_prefer_server_ciphers on;
        ssl_ciphers 'ECDH+AESGCM:ECDH+AES256:!DH+3DES:!ADH:!AECDH:!MD5:!ECDHE-RSA-AES256-SHA384:!ECDHE-RSA-AES256-SHA:!ECDHE-RSA-AES128-SHA256:!ECDHE-RSA-AES128-SHA:!RC2:!RC4:!DES:!EXPORT:!NULL:!SHA1';
        ssl_buffer_size 8k;
        ssl_dhparam ${ssl_paths[DH_PARAMS_PATH]};
        ssl_ecdh_curve secp384r1;
        ssl_stapling on;
        ssl_stapling_verify on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
EOF
}

#######################################
# A more restrictive TLS 1.3 configuration, which disables TLS 1.2 and lower
# Arguments:
#  None
#######################################
tls_protocol_one_three_restrict() {
    cat <<- EOF
        ssl_protocols TLSv1.3;
EOF
}

#######################################
# Configures the certificates for HTTPS
# Globals:
#   DOMAIN_NAME
#   INTERNAL_LETS_ENCRYPT_DIR
#   certs
#   internal_dirs
# Arguments:
#  None
#######################################
configure_certs() {
      certs="
        ssl_certificate ${internal_dirs[INTERNAL_LETS_ENCRYPT_DIR]}/live/${DOMAIN_NAME}/fullchain.pem;
        ssl_certificate_key ${internal_dirs[INTERNAL_LETS_ENCRYPT_DIR]}/live/${DOMAIN_NAME}/privkey.pem;
        ssl_trusted_certificate ${internal_dirs[INTERNAL_LETS_ENCRYPT_DIR]}/live/${DOMAIN_NAME}/fullchain.pem;"
}

#######################################
# Configures the security headers for HTTPS
# Globals:
#   USE_LETS_ENCRYPT
#   security_headers
# Arguments:
#  None
#######################################
configure_security_headers() {
  security_headers="
            # Prevent clickjacking by instructing the browser to deny rendering iframes
            add_header X-Frame-Options 'DENY' always;

            # Protect against MIME type sniffing security vulnerabilities
            add_header X-Content-Type-Options nosniff always;

            # Enable XSS filtering in browsers that support it
            add_header X-XSS-Protection '1; mode=block' always;

            # Control the information that the browser includes with navigations away from your site
            add_header Referrer-Policy 'strict-origin-when-cross-origin' always;

            # Content Security Policy
            # The CSP restricts the sources of content like scripts, styles, images, etc. to increase security
            # 'self' keyword restricts loading resources to the same origin as the document
            # Adjust the policy directives based on your application's specific needs
            add_header Content-Security-Policy \"default-src 'self'; script-src 'self' 'unsafe-inline'; object-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://*.tile.openstreetmap.org; media-src 'none'; frame-src 'none'; font-src 'self'; connect-src 'self';\";"

  if [[ $USE_LETS_ENCRYPT == "yes" ]]; then
    security_headers+="

            # HTTP Strict Transport Security (HSTS) for 1 year, including subdomains
            add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;"
  fi
}

#######################################
# Configures the ACME challenge block for HTTPS/LE
# Globals:
#   USE_LETS_ENCRYPT
#   acme_challenge_server_block
#   server_name
# Arguments:
#  None
#######################################
configure_acme_challenge() {
    if [[ $USE_LETS_ENCRYPT == "yes" ]]; then
        acme_challenge_server_block="server {
          listen 80;
          listen [::]:80;
          server_name ${server_name};
          location / {
              return 301 https://\$host\$request_uri;
          }
          location /.well-known/acme-challenge/ {
              allow all;
              root /usr/share/nginx/html;
          }
      }"
  fi
}

#######################################
# Checks if an existing NGINX configuration exists and backs it up if it does
# Globals:
#   NGINX_CONF_FILE
# Arguments:
#  None
#######################################
backup_existing_config() {
    if [[ -f ${NGINX_CONF_FILE}   ]]; then
        cp "${NGINX_CONF_FILE}" "${NGINX_CONF_FILE}.bak"
        echo "Backup created at \"${NGINX_CONF_FILE}.bak\""
  fi
}

#######################################
# Generates an NGINX configuration for the QR endpoint if the release branch is full-release
# Globals:
#   BACKEND_PORT
#   backend_scheme
#   release_branch
# Arguments:
#  None
#######################################
write_endpoints() {
        if [[ $release_branch == "full-release" ]]; then
    local endpoint="/qr/"

    local proxy_pass="proxy_pass ${backend_scheme}://backend:${BACKEND_PORT};"
    local proxy_set_header_host="proxy_set_header Host \$host;"
    local proxy_set_header_x_real_ip="proxy_set_header X-Real-IP \$remote_addr;"
    local proxy_set_header_x_forwarded_for="proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"

    echo "location ${endpoint} {"
    echo "            ${proxy_pass}"
    echo "            ${proxy_set_header_host}"
    echo "            ${proxy_set_header_x_real_ip}"
    echo "            ${proxy_set_header_x_forwarded_for}"
    echo "        }"
  fi
}

#######################################
# Writes the NGINX configuration to the NGINX configuration file
# Globals:
#   NGINX_CONF_FILE
#   acme_challenge_server_block
#   certs
#   default_port_directive
#   resolver_settings
#   security_headers
#   server_name
#   ssl_listen_directive
#   ssl_mode_block
# Arguments:
#  None
#######################################
write_nginx_config() {
    cat <<- EOF > "${NGINX_CONF_FILE}"
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        ${default_port_directive}
        ${ssl_listen_directive}
        server_name ${server_name};
        ${ssl_mode_block}
        ${resolver_settings}
        ${certs}

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files \$uri \$uri/ /index.html;
            ${security_headers}
        }

        $(write_endpoints)
    }
    ${acme_challenge_server_block}
}
EOF

        cat "${NGINX_CONF_FILE}"
        echo "NGINX configuration written to ${NGINX_CONF_FILE}"
}
