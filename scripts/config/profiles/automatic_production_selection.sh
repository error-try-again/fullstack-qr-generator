#!/usr/bin/env bash

set -euo pipefail

#######################################
# Applies the production configuration profile to the current environment.
# Arguments:
#  None
#######################################
function automatic_production_selection() {
  apply_profile "${INSTALL_PROFILE}" "prod_config"
}
