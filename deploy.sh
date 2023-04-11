#!/bin/bash
set -e

###############################################################################
# This script can be used to deploy the resources in this project. 
#
# When run for the first time, don't specify any options. Just run `./init.sh`.
# It will run using local state. This is needed to bootstrap all of the
# resources. It then migrates the state for one of the modules only, because
# run-all causes Terragrunt to try to create multiple S3 backends at the same
# time as it runs multiple threads in parallel. Then it goes back and migrates
# the state for all modules. Once the resources are deployed, the script will
# push all of the code into the CodeCommit repository.
#
# If you want to run this script once everything has already been deployed,
# you should use remote state and skip pushing the code into CodeCommit using
# the -r and -p options `./init.sh -r -p`
###############################################################################

function usage {
    echo "DESCRIPTION:"
    echo "  Script for initializing resources in this project. See README for more details."
    echo "  *** MUST BE RUN WITH ADMIN CREDENTIALS FOR DEPLOYMENT ACCOUNT ***"
    echo ""
    echo "USAGE:"
    echo "  init.sh [-r] [-p]"
    echo ""
    echo "OPTIONS"
    echo "  -r   use remote state, can be used after the inital run"
    echo "  -p   skip pushing code to remote repo"
}

function pushd () {
    command pushd "$@" > /dev/null
}

function popd () {
    command popd "$@" > /dev/null
}

while getopts "rph" option; do
    case ${option} in
        r ) SKIP_LOCAL_STATE=1;;
        p ) SKIP_PUSH_CODE=1;;
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

if [[ -z "${SKIP_LOCAL_STATE}" ]]; then
    echo "=== RUNNING DEPLOYMENT WITH LOCAL STATE ==="

    echo "Putting in place temporary local state terraform module"
    rm -f terragrunt.hcl
    cp terragrunt-local.hcl terragrunt.hcl
else
    echo "Putting in place remote state terraform module"
    rm -f terragrunt.hcl
    cp terragrunt-remote.hcl terragrunt.hcl
fi

pushd ./infrastructure

echo "Running terragrunt init"
terragrunt run-all init
echo "Running terragrunt apply"
terragrunt run-all apply

if [[ -z "${SKIP_LOCAL_STATE}" ]]; then

    popd
    
    echo "Putting in place remote state terraform module"
    rm -f terragrunt.hcl
    cp terragrunt-remote.hcl terragrunt.hcl

    pushd ./infrastructure

    # Here we initialise remote state only in one module so that the
    # relevant S3 bucket and DynamoDB table is created. This is because
    # Terragrunt run-all runs tasks in parallel and would therefore
    # attempt to create more than one remote state and error out
    echo "Initialising remote S3 state"
    pushd ./artifacts-bucket
    terragrunt init -force-copy --terragrunt-non-interactive
    popd

    # Now that the S3 remote state bucket already exists, use it
    # to initialise the remaining modules
    terragrunt run-all init -force-copy --terragrunt-non-interactive

fi

pushd ./codecommit
REPO_NAME=$(terragrunt output -raw repository_name)
echo "Stored CodeCommit repository name: $REPO_NAME"
popd

popd

popd # go to root folder of this repo

if [[ -z "${SKIP_PUSH_CODE}" ]]; then
    echo "=== PREPARING TO PUSH CODE TO CODE COMMIT REPOSITORY ==="
    echo "Cleaning up Terragrunt and Terraform cache"
    find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \; # clean Terragrunt cache data
    find . -type d -name ".terraform" -prune -exec rm -rf {} \; # clean Terraform cache data
    echo "Preparing source code folder"
    rm -rf repository    # clean if already exists
    mkdir repository
    echo "Cloning CodeCommig repository: codecommit://$REPO_NAME in to repository folder"
    git clone codecommit://$REPO_NAME repository
    echo "Transfering source code into cloned repository folder"
    rsync -av . ./repository --exclude repository --exclude .git
    pushd ./repository
    echo "Running git add and commit for initial commit"
    git --git-dir=.git add .
    git --git-dir=.git commit -m "Bootstrap commit"
    echo "Pushing to remote repository"
    git --git-dir=.git push
    popd
    echo "Cleaning up repository folder"
    rm -rf repository
fi

echo "You can now clone the repository into a new folder and work with git going forward."
echo "The deployed CI/CD pipeline will take care of the build and deployment process."
echo ""
echo "See README for more information about how to best access the CodeCommit repository using git."
