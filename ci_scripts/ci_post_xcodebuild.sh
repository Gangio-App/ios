#!/bin/sh

#  ci_post_xcodebuild.sh.sh
#  Stoat
#
#  Created & Design by github.com/benyigit on 21/04/2026.
#

# Disable Sentry for now until until we setup our instance again

# set -e

# if [ ! -d "$CI_ARCHIVE_PATH" ]; then
#     echo "Archive does not exist, skipping Sentry upload"
#     exit 0
# fi

# export INSTALL_DIR=$PWD

# if [[ $(command -v sentry-cli) == "" ]]; then
#     echo "Installing Sentry CLI"
#     curl -sL https://sentry.io/get-cli/ | bash
# fi

# echo "Authenticate to Sentry"
# ./sentry-cli login --auth-token $SENTRY_AUTH_TOKEN

# echo "Uploading dSYM to Sentry"
# ./sentry-cli debug-files upload --include-sources -o stoat -p apple-ios $CI_ARCHIVE_PATH --force-foreground
