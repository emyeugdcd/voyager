#!/usr/bin/env bash

# Voyager Infrastructure Teardown Script
# Destroys resources sequentially to respect dependencies and avoid orphaned resources.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================================="
echo "VOYAGER INFRASTRUCTURE TEARDOWN"
echo "============================================================================="
echo "WARNING: This will destroy all deployed resources in Test and Prod!"
read -p "Are you absolutely sure you want to proceed? (yes/no): " CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Teardown cancelled."
  exit 0
fi

# 1. Destroy Production Environment
echo "-----------------------------------------------------------------------------"
echo "1. Destroying Production Environment..."
echo "-----------------------------------------------------------------------------"
if cd "${PROJECT_ROOT}/terraform/environments/prod"; then
  terraform init
  terraform destroy -auto-approve
else
  echo "Production environment directory not found, skipping."
fi

# 2. Destroy Test Environment
echo "-----------------------------------------------------------------------------"
echo "2. Destroying Test Environment..."
echo "-----------------------------------------------------------------------------"
if cd "${PROJECT_ROOT}/terraform/environments/test"; then
  terraform init
  terraform destroy -auto-approve
else
  echo "Test environment directory not found, skipping."
fi

# 3. Optional: Destroy Shared Resources
echo "-----------------------------------------------------------------------------"
echo "3. Shared Resources (ACR, Service Principal)"
echo "-----------------------------------------------------------------------------"
read -p "Do you also want to destroy Shared Resources? (yes/no): " DESTROY_SHARED

if [[ "${DESTROY_SHARED}" == "yes" ]]; then
  if cd "${PROJECT_ROOT}/terraform/environments/shared"; then
    terraform init
    terraform destroy -auto-approve
  else
    echo "Shared environment directory not found, skipping."
  fi
else
  echo "Shared resources preserved."
fi

echo "============================================================================="
echo "TEARDOWN SEQUENCE COMPLETE"
echo "============================================================================="
