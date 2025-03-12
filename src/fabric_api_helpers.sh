#!/bin/bash
#set -o errexit


# source ./config/.env

#############################
##    Utility functions
#############################
print_style () {
    case "$2" in
        "info")
            COLOR="96m"
            ;;
        "success")
            COLOR="92m"
            ;;
        "warning")
            COLOR="93m"
            ;;
        "danger")
            COLOR="91m"
            ;;
        "action")
            COLOR="32m"
            ;;
        *)
            COLOR="0m"
            ;;
    esac

    STARTCOLOR="\e[$COLOR"
    ENDCOLOR="\e[0m"
    printf "$STARTCOLOR%b$ENDCOLOR" "$1"
}

log() {
    # This function takes a string as an argument and prints it to the console to stderr
    # if a second argument is provided, it will be used as the style of the message
    # Usage: log "message" "style"
    # Example: log "Hello, World!" "info"
    local message=$1
    local style=${2:-}

    if [[ -z "$style" ]]; then
        echo -e "$(print_style "$message" "default")" >&2
    else
        echo -e "$(print_style "$message" "$style")" >&2
    fi
}

# Helper to make REST API calls to Fabric API
rest_call(){
    local method=$1
    local uri=$2
    local query=${3:-}
    local output=${4:-"json"}
    local body=${5:-}

    if [ -z "$query" ] && [ -z "$body" ]; then
        az rest --method $method --uri "$FABRIC_API_BASEURL/$uri" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --output $output
        return
    fi

    if [ -n "$query" ] && [ -z "$body" ]; then
        az rest --method $method --uri "$FABRIC_API_BASEURL/$uri" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --query "$query" --output $output
        return
    fi

    if [ -z "$query" ] && [ -n "$body" ]; then
        az rest --method $method --uri "$FABRIC_API_BASEURL/$uri" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --output $output --body "$body"
    fi

    if [ -n "$query" ] && [ -n "$body" ]; then
        az rest --method $method --uri "$FABRIC_API_BASEURL/$uri" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --query "$query" --output $output --body "$body"
        return
    fi

}

long_running_operation_polling() {
    local uri=$1
    local retryAfter=$2
    local requestHeader="Authorization: Bearer $FABRIC_USER_TOKEN"

    log "Polling long running operation ID has been started with a retry-after time of $retryAfter seconds."

    while true; do
        operationState=$(curl -s -H "$requestHeader" "$uri")
        status=$(echo "$operationState" | jq -r '.status')

        if [[ "$status" == "NotStarted" || "$status" == "Running" ]]; then
            sleep 20
        else
            break
        fi
    done

    if [ "$status" == "Failed" ]; then
        log "The long running operation has been completed with failure. Error response: $(echo "$operationState" | jq '.')"
    else
        log "Operation successfully completed." "success"
        item=$(curl -s -H "$requestHeader" "$uri/result")
        echo "$item"
    fi
}

function is_token_expired {
    # Ensure the token is set
    if [ -z "$FABRIC_USER_TOKEN" ]; then
        log "No FABRIC_USER_TOKEN set."
        echo 1
        return
    fi

    # Extract JWT payload (assumes token format: header.payload.signature)
    payload=$(echo "$FABRIC_USER_TOKEN" | cut -d '.' -f2 | sed 's/-/+/g; s/_/\//g;')
    # Add missing padding if needed
    mod4=$(( ${#payload} % 4 ))
    if [ $mod4 -ne 0 ]; then
        payload="${payload}$(printf '%0.s=' $(seq 1 $((4 - mod4))))"
    fi

    # Decode payload and extract the expiration field using jq
    exp=$(echo "$payload" | base64 -d 2>/dev/null | jq -r '.exp')
    if [ -z "$exp" ]; then
        log "Unable to parse token expiration."
        echo 1
        return
    fi

    # Compare expiration with current time
    current=$(date +%s)
    if [ "$current" -ge "$exp" ]; then
        # Token is expired
        echo 1
    else
        # Token is not expired
        echo 0
    fi
}

#############################
##    Fabric functions
#############################

#----------------------------
# Workspaces
#----------------------------

# Function to get all workspaces names
get_workspace_names(){
    rest_call get "workspaces" "value[].displayName" tsv
    #az rest --method get --uri "$FABRIC_API_BASEURL/workspaces" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --query "value[].id" -o tsv
}

# Get workspace displayName by specifying a workspace id
get_workspace_name(){
    local workspace_id=$1
    rest_call get "workspaces/$workspace_id" "displayName" tsv
    #az rest --method get --uri "$FABRIC_API_BASEURL/workspaces/$workspace_id" --headers "Authorization=Bearer $token"
}

# Get workspace id by specifying a workspace displayName
get_workspace_id(){
    local workspace_name=$1
    rest_call get "workspaces" "value[?displayName=='$workspace_name'].id" tsv | tr -d '\r'
    #az rest --method get --uri "$FABRIC_API_BASEURL/workspaces/$workspace_id" --headers "Authorization=Bearer $token"
}

# Create a new workspace with the specified name using capacity id
create_workspace(){
    local workspace_name=$1
    local capacity_id=$2
    body=$(cat <<EOF
{"displayName" : "$workspace_name", "capacityId" : "$capacity_id"}
EOF
)
    
    rest_call "POST" "workspaces" "id" "tsv" "$body"
}

get_or_create_workspace() {
    # given a workspace name returns its id
    # if the workspace does not exist, creates it and returns its id
    # requires a capacity id and a workspace name

    local workspace_name=$1
    local capacity_id=$2

    workspace_id=$(get_workspace_id "$workspace_name")

    if [ -z "$workspace_id" ]; then
        log "A workspace with the requested name $workspace_name was not found, creating new workspace." 
        workspace_id=$(create_workspace "$workspace_name" "$capacity_id")
        log "Workspace $workspace_name with id $workspace_id was created." "success"
    else
        log "Workspace $workspace_name with id $workspace_id was found." "success"
    fi
    echo $workspace_id
}

#----------------------------
# Items
#----------------------------


get_workspace_items(){
    local workspace_id=$1
    # get all workspace items
    rest_call get "workspaces/$workspace_id/items" "value" "json"
}

# workspaces=$(get_workspaces)
# # az rest --method get --uri "$FABRIC_API_BASEURL/workspaces" --headers "Authorization=Bearer $token" --query "value[].{name:displayName, id:id, capacity_id:capacity_id}" -o json
# for workspace in $workspaces; do
#     echo $workspace #| jq -r '.name, .id, .capacity_id'
# done

# get_workspace_by_id "7edb50fc-82bd-4add-8521-7b8cc6cb0fc1"

# get_workspace_names

# get_or_create_workspace "test_workspace" $FABRIC_CAPACITY_ID
get_item_id(){
    local workspace_id=$1
    local item_name=$2
    local item_type=$3
    # rest_call get "workspaces/$workspace_id/items?type=$item_type" "value[?displayName=='$item_name'].id" tsv | tr -d '\r'
    echo $(get_item_by_name "$workspace_id" "$item_name" "$item_type" | jq -r '.id')
}

get_item_by_name(){
    local workspace_id=$1
    local item_name=$2
    local item_type=$3
    rest_call get "workspaces/$workspace_id/items?type=$item_type" "value[?displayName=='$item_name'] | [0].{description: description, displayName: displayName, type: type, id: id}" "json" | tr -d '\r'
}

get_and_store_item(){
    local workspace_id=$1
    local item_name=$2
    local item_type=$3
    local folder=$4
    # This function retrieves the definition of an item
    # requires as inputs the workspace id, the item name and the item type
    # If the item type supports retrieving the definition then it will return that
    # else it will return the item metadata

    if [ $item_type == "Notebook" ] || [ $item_type == "DataPipeline" ]; then
        # When the item supports definition then use the getDefinition API
        item_definition=$(get_item_definition "$workspace_id" "$item_name" "$item_type")
        if [ -z "$item_definition" ]; then
            log "Failed to retrieve definition for item $item_name of type $item_type."
            return 1
        fi
        log "Saving definition to file..."
        store_item_definition "$folder" "$item_name" "$item_type" "$item_definition"
    else
        item_metadata=$(rest_call get "workspaces/$workspace_id/items?type=$item_type" "value[?displayName=='$item_name'] | [0].{description: description, displayName: displayName, type: type}" "json" | tr -d '\r')
        if [ -z "$item_metadata" ]; then
            log "Item $item_name of type $item_type was not found in the workspace."
            return 1
        fi
        log "Saving item metadata..."
        store_item_metadata "$folder" "$item_name" "$item_type" "$item_metadata"
    fi
}

store_item_metadata(){
    local folder=$1
    local item_name=$2
    local item_type=$3
    local item_metadata=$4
    local output_folder="$folder/$item_name.$item_type"
    mkdir -p "$output_folder"
    platform_file=$(cat <<EOF
{
  "\$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": $item_metadata,
  "config": {
    "version": "2.0",
    "logicalId": "00000000-0000-0000-0000-000000000000"
  }
}
EOF
)
    echo "$platform_file" | jq '.' > "$output_folder/.platform"
    log "Item metadata saved to $output_folder" "success"
}

get_item_definition(){
    local workspace_id=$1
    local item_name=$2
    local item_type=$3

    # Get item id
    item_id=$(get_item_id "$workspace_id" "$item_name" "$item_type")
    if [ -z "$item_id" ]; then
        log "Item $item_name of type $item_type was not found in the workspace."
        return 1
    fi
    log "Found item '$item_name' with ID: '$item_id'"
    log "retrieving item definition for $item_name"
    # then get item definition
    # if itemType=Notebook then filter for format=ipynb
    if [ "$item_type" == "Notebook" ]; then
        uri="workspaces/$workspace_id/items/$item_id/getDefinition?format=ipynb"
    else
        uri="workspaces/$workspace_id/items/$item_id/getDefinition"
    fi
    response=$(curl -sSi -X POST -H "Authorization: Bearer $FABRIC_USER_TOKEN" "$FABRIC_API_BASEURL/$uri" --data "")
    status_code=$(echo "$response" | head -n 1 | cut -d' ' -f2)

    if [ "$status_code" != 202 ] && [ "$status_code" != 200 ]; then
        log "Failed to retrieve definition for item $item_name of type $item_type."
        return 1
    fi
    if [ "$status_code" == 200 ]; then
        response=$(echo "$response" | tail -n 1)
        echo "$response"
        return 0
    else
        location=$(echo "$response" | grep -i ^location: | cut -d: -f2- | sed 's/^ *\(.*\).*/\1/' | tr -d '\r')
        retry_after=$(echo "$response" | grep -i ^retry-after: | cut -d: -f2- | sed 's/^ *\(.*\).*/\1/' | tr -d '\r')
        response=$(long_running_operation_polling "$location" "$retry_after")
        if [ -z "$response" ]; then
            log "Failed to retrieve definition for item $item_name of type $item_type."
            return 1
        fi
    fi

    echo "$response"
}

store_item_definition(){
    local folder=$1
    local item_name=$2
    local item_type=$3
    local definitionJson=$4
    local output_folder="$folder/$item_name.$item_type"
    mkdir -p "$output_folder"
    # for each path element in the item definition json
    # convert the base64 encoded content to a file
    # using the payloadType, payload and path elements
    # for part in $(echo "$definitionJson" | jq -r '.definition.parts[] | @base64'); do
    #     part=$(echo "$part" | base64 --decode)
    for part in $(echo "$definitionJson" | jq -r -c '.definition.parts[]'); do
        path=$(echo "$part" | jq -r -c '.path')
        payloadType=$(echo "$part" | jq -r -c '.payloadType')
        payload=$(echo "$part" | jq -r -c '.payload')
        log "Saving item definition part '$path' in '$output_folder'"
        if [ "$payloadType" == "InlineBase64" ]; then
            echo -n "$payload" | base64 -d > "$output_folder/$path"
        else
            echo -n "$payload" > "$output_folder/$path"
        fi
    done 
    log "Item definition saved to $output_folder" "success"
}

create_or_update_workspace_item() {
    local workspace_id=$1
    local workspaceItems=$2
    local folder=$3
    local repoItems=$4

    metadataFilePath="$folder/$itemMetadataFileName"
    if [ -f "$metadataFilePath" ]; then
        itemMetadata=$(cat "$metadataFilePath")
        log "Found item metadata for $(echo "$itemMetadata" | jq -r '.displayName')"
    else
        log "Item $folder does not have the required metadata file, skipping."
        return
    fi

    definitionFilePath="$folder/$itemDefinitionFileName"
    if [ -f "$definitionFilePath" ]; then
        itemDefinition=$(cat "$definitionFilePath")
        log "Found item definition for $(echo "$itemMetadata" | jq -r '.displayName')"
        contentFiles=$(find "$folder" -type f ! -name "$itemMetadataFileName" ! -name "$itemDefinitionFileName" ! -name "$itemConfigFileName")
        if [ -n "$contentFiles" ]; then
            log "Found $(echo "$contentFiles" | wc -l) content file(s) for $(echo "$itemMetadata" | jq -r '.displayName')"
            for part in $(echo "$itemDefinition" | jq -r '.definition.parts[] | @base64'); do
                part=$(echo "$part" | base64 --decode)
                file=$(echo "$contentFiles" | grep "$(echo "$part" | jq -r '.path')")
                itemContent=$(cat "$file")
                base64Content=$(echo -n "$itemContent" | base64)
                part=$(echo "$part" | jq --arg payload "$base64Content" '.payload = $payload')
                itemDefinition=$(echo "$itemDefinition" | jq --argjson part "$part" '.definition.parts |= map(if .path == $part.path then $part else . end)')
            done
            echo "$itemDefinition" | jq '.' > "$definitionFilePath"
            log "Updated item definition payload with content file for $(echo "$itemMetadata" | jq -r '.displayName')"
        else
            log "Missing content file or found more than one content file, skipping update definition for $folder."
            return
        fi
    fi

    configFilePath="$folder/$itemConfigFileName"
    if [ ! -f "$configFilePath" ] || [ "$resetConfig" == "true" ]; then
        log "No $itemConfigFileName file found, creating new file."
        itemConfig=$(jq -n --arg logicalId "$(uuidgen)" '{logicalId: $logicalId}')
        echo "$itemConfig" | jq '.' > "$configFilePath"
    else
        itemConfig=$(cat "$configFilePath")
        log "Found item config file for $folder. Item missing objectId? $(echo "$itemConfig" | jq -r 'has("objectId") | not'). Item missing logicalId? $(echo "$itemConfig" | jq -r 'has("logicalId") | not')"
    fi

    if [ -z "$(echo "$itemConfig" | jq -r '.objectId')" ]; then
        log "Item $folder does not have an associated objectId, creating new Fabric item of type $(echo "$itemMetadata" | jq -r '.type') with name $(echo "$itemMetadata" | jq -r '.displayName')."
        item=$(create_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition")
        itemConfig=$(echo "$itemConfig" | jq --arg objectId "$(echo "$item" | jq -r '.id')" '.objectId = $objectId')
        echo "$itemConfig" | jq '.' > "$configFilePath"
        repoItems+=("$(echo "$item" | jq -r '.id')")
    else
        item=$(echo "$workspaceItems" | jq -r ".[] | select(.id == \"$(echo "$itemConfig" | jq -r '.objectId')\")")
        if [ -z "$item" ]; then
            log "Item $(echo "$itemConfig" | jq -r '.objectId') of type $(echo "$itemMetadata" | jq -r '.type') was not found in the workspace, creating new item."
            item=$(create_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition")
            itemConfig=$(echo "$itemConfig" | jq --arg objectId "$(echo "$item" | jq -r '.id')" '.objectId = $objectId')
            echo "$itemConfig" | jq '.' > "$configFilePath"
            repoItems+=("$(echo "$item" | jq -r '.id')")
        else
            repoItems+=("$(echo "$itemConfig" | jq -r '.objectId')")
            log "Item $(echo "$itemConfig" | jq -r '.objectId') of type $(echo "$item" | jq -r '.type') was found in the workspace, updating item."
            update_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition" "$itemConfig"
        fi
    fi
    echo "${repoItems[@]}"
}