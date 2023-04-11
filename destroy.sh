#!/bin/bash
set -e

###############################################################################
# This script can be used to destroy the resources in this project. It assumes
# that you are using remote state. It will use the terragrunt-local.hcl module
# and then re-initialise the state back to local state. This ensures that we
# can use the credentials of the environment (e.g. AWS_PROFILE environment
# variable) and not the roles that the CI/CD pipeline would normally use. We
# can't use the CI/CD roles, because they need to be destroyed too. Once all
# the resources are destroyed the script then also deletes the Terraform state
# management resources.
###############################################################################

function usage {
    echo "DESCRIPTION:"
    echo "  Script for destroying resources in this project. See README for more details."
    echo "  *** MUST BE RUN WITH ADMIN CREDENTIALS FOR DEPLOYMENT ACCOUNT ***"
    echo ""
    echo "USAGE:"
    echo "  destroy.sh"
}

function pushd () {
    command pushd "$@" > /dev/null
}

function popd () {
    command popd "$@" > /dev/null
}

while getopts "h" option; do
    case ${option} in
        h )
            usage
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            exit 1
            ;;
    esac
done

pushd ./src

echo "Putting in place local state Terragrunt module"
rm -f terragrunt.hcl
cp terragrunt-local.hcl terragrunt.hcl

pushd ./infrastructure

# echo "Moving S3 state to local state"
terragrunt run-all init -force-copy --terragrunt-non-interactive

# echo "Running terragrunt destroy on all resources"
terragrunt run-all destroy

popd

echo "Destroying Terraform state resources"

echo "Deleting DynamoDB state locking table"
DYNAMODB_TABLE=$(yq '.terraform_state_dynamodb_table' common_vars.yaml)
aws dynamodb delete-table --table-name $DYNAMODB_TABLE

NAMESPACE=$(yq '.namespace' common_vars.yaml)
NAME=$(yq '.name' common_vars.yaml)
ENVIRONMENT=$(yq '.environment' common_vars.yaml)
STATE_BUCKET=$(yq '.terraform_state_bucket' common_vars.yaml)

BUCKET_NAME=$NAMESPACE-$NAME-$ENVIRONMENT-deployment-$STATE_BUCKET

echo "Emptying S3 state bucket"

aws s3api delete-objects \
  --bucket $BUCKET_NAME \
  --no-cli-pager \
  --delete \
    "$(aws s3api list-object-versions \
      --bucket $BUCKET_NAME \
      --no-paginate \
      --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' \
      --no-cli-pager)" || true

aws s3api delete-objects \
  --bucket $BUCKET_NAME \
  --delete \
  --no-cli-pager \
    "$(aws s3api list-object-versions \
      --bucket $BUCKET_NAME \
      --no-paginate \
      --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}' \
      --no-cli-pager)" || true

echo "Deleting S3 state bucket"
aws s3api delete-bucket --bucket $BUCKET_NAME

# popd

echo "Resources have been destroyed"