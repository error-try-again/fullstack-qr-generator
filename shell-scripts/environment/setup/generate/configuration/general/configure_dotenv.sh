#!/bin/bash

#######################################
# description
# Globals:
#   BACKEND_DIR
#   BACKEND_PORT
#   origin
# Arguments:
#  None
#######################################
configure_dot_env() {
  cat << EOF > "$BACKEND_DIR/.env"
ORIGIN=$origin
PORT=$BACKEND_PORT
EOF
}
