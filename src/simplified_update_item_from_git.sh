#!/bin/bash

# -----------------------------------------------------------------------------
# Script to upload the definition of a Fabric item (e.g., Dataset, Pipeline, etc.)
# from local filesystem to the specified Microsoft Fabric workspace.
# The script checks if the API token is expired and refreshes it if needed.
# It also retrieves the workspace ID based on the provided workspace name.
# -----------------------------------------------------------------------------
set -e

. ./src/fabric_api_helpers.sh

# Load environment variables from the .env file
source ./config/.env

# Validate input arguments: workspaceName, itemName, itemType, folder
if [ "$#" -ne 4 ]; then
    log "Usage: $0 <workspaceName> <item-folder>"
    exit 1
fi

workspaceName="$1"   # Fabric workspace name
item_folder="$2"     # The source folder where the item definition files are located

# Check if the item folder exists
if [ ! -d "$item_folder" ]; then
    log "Error: Item folder '$item_folder' does not exist."
    exit 1
fi
# Check if the item folder contains a .platform file
if [ ! -f "$item_folder/.platform" ]; then
    log "Error: No .platform file found in the item folder '$item_folder'."
    exit 1
fi

# Extract folder, item name, and item type variables from the item folder name
read -r item_name item_type <<< "$( item_name_and_type "$item_folder" )"

# Check required environment variables
if [ -z "$FABRIC_API_BASEURL" ] || [ -z "$FABRIC_USER_TOKEN" ]; then
    log "FABRIC_API_BASEURL or FABRIC_USER_TOKEN is not set in the env file."
    exit 1
fi

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
# Get the workspace ID from Fabric
# -----------------------------------------------------------------------------
workspaceId=$(get_workspace_id "$workspaceName")
if [ -z "$workspaceId" ]; then
    log "Error: Could not find workspace $workspaceName."
    exit 1
fi
log "Found workspace '$workspaceName' with ID: '$workspaceId'"

# -----------------------------------------------------------------------------
# call the create_or_update_item function to create or update the item
# -----------------------------------------------------------------------------

# Upload the item definition
upload_item "$workspaceId" "$itemName" "$itemType" "$item_folder"
log "Script successfully completed." "success"
# -----------------------------------------------------------------------------
# Function to get the item type based on the folder name
# -----------------------------------------------------------------------------
get_item_type() {
    local folder="$1"
    # Extract the item type from the folder name
    # This is a placeholder logic; you may need to adjust it based on your naming convention
    case "$folder" in
        *Dataset*) echo "Dataset" ;;
        *Pipeline*) echo "Pipeline" ;;
        *Lakehouse*) echo "Lakehouse" ;;
        *Environment*) echo "Environment" ;;
        *) echo "Unknown" ;;
    esac
}
# -----------------------------------------------------------------------------
# Function to upload the item definition
# -----------------------------------------------------------------------------
upload_item() {
    local workspaceId="$1"
    local itemName="$2"
    local itemType="$3"
    local item_folder="$4"

    # Check if the item folder contains a .platform file
    if [ ! -f "$item_folder/.platform" ]; then
        log "Error: No .platform file found in the item folder '$item_folder'."
        exit 1
    fi

    # Upload the item definition using the Fabric API
    # This is a placeholder logic; you may need to adjust it based on your API endpoint and parameters
    log "Uploading item '$itemName' of type '$itemType' to workspace ID '$workspaceId'..."
}
    # Example API call (replace with actual API endpoint and parameters)
    response=$(curl -X POST "$FABRIC_API_BASEURL/workspaces/$workspaceId/items" \
        -
        -H "Authorization: Bearer $
FABRIC_USER_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"$itemName"'",
            "type": "'"$itemType"'",
            "folder": "'"$item_folder"'"
        }')

    # Check the response for success or failure
    if [[ "$response" == *"success"* ]]; then
        log "Item '$itemName' uploaded successfully."
    else
        log "Error uploading item '$itemName': $response"
        exit 1
    fi
}
# -----------------------------------------------------------------------------
# Function to log messages
# -----------------------------------------------------------------------------
log() {
    local message="$1"
    local status="${2:-info}"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$status] $message"
}
# -----------------------------------------------------------------------------
# Function to check if the API token is expired
# -----------------------------------------------------------------------------
