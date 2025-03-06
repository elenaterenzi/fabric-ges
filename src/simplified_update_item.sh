#!/bin/bash
set -e

. ./src/fabric_api_helpers.sh

source ./config/.env

# Validate input arguments: workspaceName, itemName, itemType, folder
if [ "$#" -ne 4 ]; then
    log "Usage: $0 <workspaceName> <itemName> <itemType> <folder>"
    exit 1
fi

workspaceName="$1"   # Fabric workspace name
itemName="$2"        # Fabric item name whose definition should be downloaded
itemType="$3"        # Fabric item type used to filter the results
folder="$4"          # Destination folder for the definition file

# Check required environment variables
if [ -z "$FABRIC_API_BASEURL" ] || [ -z "$FABRIC_USER_TOKEN" ]; then
    log "FABRIC_API_BASEURL or FABRIC_USER_TOKEN is not set in the env file."
    exit 1
fi

# create destination folder if needed
mkdir -p "$folder"

# -----------------------------------------------------------------------------
# Check if the API token is expired and refresh if needed using refresh_api_token.sh
# -----------------------------------------------------------------------------
if [[ $(is_token_expired) = "1" ]]; then
    log "API token has expired. Refreshing token..."
    # Call refresh_api_token.sh.
    ./src/refresh_api_token.sh 
    # Reload environment variables after token refresh.
    source ./config/.env
    log "Token refreshed."
fi

# -----------------------------------------------------------------------------
# Get the workspace ID from Fabric using a helper function 
# -----------------------------------------------------------------------------
workspaceId=$(get_workspace_id "$workspaceName")
if [ -z "$workspaceId" ]; then
    log "Error: Could not find workspace $workspaceName."
    exit 1
fi
log "Found workspace '$workspaceName' with ID: '$workspaceId'"

# -----------------------------------------------------------------------------
# Retrieve the item definition for the specified item using helper function
# Now filtered by both item name and item type
# -----------------------------------------------------------------------------
definitionJson=$(get_item_definition "$workspaceId" "$itemName" "$itemType")
if [ -z "$definitionJson" ]; then
    log "Error: Failed to retrieve definition for item $itemName of type $itemType."
    exit 1
fi

# -----------------------------------------------------------------------------
# Save the downloaded definition JSON to a file in the provided folder
# Optionally include item type in the output file name
# -----------------------------------------------------------------------------
outputFile="$folder/${itemName}-${itemType}-definition.json"
echo "$definitionJson" > "$outputFile"
log "Definition saved to $outputFile"
