#! /bin/bash

########################################################################################################################
## This script is used by the catalog pipeline to deploy the SLZ ROKS, which is a prerequisite for the WAS operator   ##
## landing zone extension, after catalog validation has completed.                                                     ##
########################################################################################################################

set -e

DA_DIR="solutions/fully-configurable"
TERRAFORM_SOURCE_DIR="tests/existing-resources"
JSON_FILE="${DA_DIR}/catalogValidationValues.json"
REGION="us-south"
RESOURCE_GROUP="geretain-test-ext-secrets-sync"
EXISTING_SECRETS_MANAGER_CRN="crn:v1:bluemix:public:secrets-manager:us-south:a/abac0df06b644a9cabc6e44f55b3880e:79c6d411-c18f-4670-b009-b0044a238667::"
TF_VARS_FILE="terraform.tfvars"

(
  cwd=$(pwd)
  cd ${TERRAFORM_SOURCE_DIR}
  echo "Provisioning prerequisite..."
  terraform init || exit 1
  # $VALIDATION_APIKEY is available in the catalog runtime
  {
    echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\""
    echo "prefix=\"eso-da-$(openssl rand -hex 2)\""
    echo "region=\"${REGION}\""
    echo "resource_group=\"${RESOURCE_GROUP}\""
  } >> "${TF_VARS_FILE}"
  terraform apply -input=false -auto-approve -var-file="${TF_VARS_FILE}" || exit 1

  existing_secrets_manager_crn_var_name="existing_secrets_manager_crn"
  existing_cluster_crn_var_name="existing_cluster_crn"
  prefix_var_name="prefix"
  prefix_var_value="$(terraform output -state=terraform.tfstate -raw prefix)"
  existing_cluster_crn_var_value="$(terraform output -state=terraform.tfstate -raw cluster_crn)"

  echo "Appending '${prefix_var_name}', '${existing_cluster_crn_var_name}', '${existing_secrets_manager_crn_var_name}' input variable values to ${JSON_FILE}..."

  cd "${cwd}"
  jq -r --arg prefix_var_name "${prefix_var_name}" \
        --arg prefix_var_value "${prefix_var_value}" \
        --arg existing_cluster_crn_var_name "${existing_cluster_crn_var_name}" \
        --arg existing_cluster_crn_var_value "${existing_cluster_crn_var_value}" \
        --arg existing_secrets_manager_crn_var_name "${existing_secrets_manager_crn_var_name}" \
        --arg existing_secrets_manager_crn_var_value "${EXISTING_SECRETS_MANAGER_CRN}" \
        '. + {($prefix_var_name): $prefix_var_value, ($existing_cluster_crn_var_name): $existing_cluster_crn_var_value, ($existing_secrets_manager_crn_var_name): $existing_secrets_manager_crn_var_value}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
