#!/usr/bin/env bash
# bashsupport disable=BP5006

set -euo pipefail

#######################################
# Resets the default state of the environment variables to the values in the .env file.
# Globals: None
# Arguments: None
#######################################
function reset_dotenv_defaults() {
  # Define the .env file name and store it in a local variable.
  local envfile=".env"

  # Check if the .env file exists. If not, print an error and exit the function with status 1.
  if [[ ! -f ${envfile} ]]; then
    echo "Error: .env file does not exist."
    return 1
  fi

  # Attempt to source (execute) the .env file to import its variables.
  # If sourcing fails, print an error and exit the function with status 1.
  if # shellcheck source=./${envfile}
    ! source "${envfile}"
  then
    echo "Error: Failed to source .env file."
    return 1
  fi

  # Initialize local variables to hold the current and default environment variables.
  local current_env
  local default_env

  # Extract all current environment variable names (before '=' character)
  # and store them as a newline-separated string in current_env.
  # If the command fails, print an error and return 1.
  if ! current_env=$(env | cut -d= -f1 | grep '^[a-zA-Z_][a-zA-Z_0-9]*$'); then
    echo "Error: Failed to extract current environment variables."
    return 1
  fi

  # Convert the newline-separated string of current environment variables into an array.
  mapfile -t current_env <<< "${current_env}"

  # Extract all variable names from the .env file (before '=' character)
  # and store them as a newline-separated string in default_env.
  # If the command fails, print an error and return 1.
  if ! default_env=$(cut -d= -f1 "${envfile}"); then
    echo "Error: Failed to read variable names from .env."
    return 1
  fi

  # Convert the newline-separated string of default environment variables from the .env file into an array.
  mapfile -t default_env <<< "${default_env}"

  # Sort both arrays of environment variables alphabetically and update the respective arrays.
  mapfile -t current_env < <(printf "%s\n" "${current_env[@]}" | sort)
  mapfile -t default_env < <(printf "%s\n" "${default_env[@]}" | sort)

  # Compare the sorted arrays of current and default environment variables.
  # Unset any variables that are in the current environment but not in the .env file.
  # If unsetting fails for any variable, print a warning but continue with the others.
  # If the entire unsetting process fails, print an error and return 1.
  comm -23 <(printf "%s\n" "${current_env[@]}") <(printf "%s\n" "${default_env[@]}") \
    | while read -r var_to_unset; do
      case ${var_to_unset} in
        -*)
          echo "Skipping invalid variable: ${var_to_unset}"
          continue
          ;;
        *)
          unset "${var_to_unset}" || {
            echo "Warning: Failed to unset ${var_to_unset}"
            continue
          }
          ;;
      esac
    done || {
    echo "Error: Failed to process unsetting variables."
    return 1
  }
}