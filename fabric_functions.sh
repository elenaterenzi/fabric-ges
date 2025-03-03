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

# Function to make REST API calls to Fabric API
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

#############################
##    Fabric functions
#############################


# Function to get all workspaces names
get_workspace_names(){
    rest_call get "workspaces" "value[].displayName" tsv
    #az rest --method get --uri "$FABRIC_API_BASEURL/workspaces" --headers "Authorization=Bearer $FABRIC_USER_TOKEN" --query "value[].id" -o tsv
}

# Get workspace displayName by specifying a workspace id
get_workspace_by_id(){
    local workspace_id=$1
    rest_call get "workspaces/$workspace_id" "displayName" tsv
    #az rest --method get --uri "$FABRIC_API_BASEURL/workspaces/$workspace_id" --headers "Authorization=Bearer $token"
}

# Get workspace id by specifying a workspace displayName
get_workspace_by_name(){
    local workspace_name=$1
    rest_call get "workspaces" "value[?displayName=='$workspace_name'].id" tsv
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

    workspace_id=$(get_workspace_by_name "$workspace_name")

    if [ -z "$workspace_id" ]; then
        log "A workspace with the requested name $workspace_name was not found, creating new workspace." 
        workspace_id=$(create_workspace "$workspace_name" "$capacity_id")
        log "Workspace $workspace_name with id $workspace_id was created." "success"
    else
        log "Workspace $workspace_name with id $workspace_id was found." "success"
    fi
    echo $workspace_id
}

get_workspace_items(){
    local workspace_id=$1
    # get all workspace items
    # does not return Semantic Models or SQL Analytics endpoints that are tied to a Lakehouse
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

create_or_update_workspace_item() {
    local workspace_id=$1
    local workspaceItems=$2
    local folder=$3
    local repoItems=$4

    metadataFilePath="$folder/$itemMetadataFileName"
    if [ -f "$metadataFilePath" ]; then
        itemMetadata=$(cat "$metadataFilePath")
        echo "Found item metadata for $(echo "$itemMetadata" | jq -r '.displayName')"
    else
        echo "Item $folder does not have the required metadata file, skipping."
        return
    fi

    definitionFilePath="$folder/$itemDefinitionFileName"
    if [ -f "$definitionFilePath" ]; then
        itemDefinition=$(cat "$definitionFilePath")
        echo "Found item definition for $(echo "$itemMetadata" | jq -r '.displayName')"
        contentFiles=$(find "$folder" -type f ! -name "$itemMetadataFileName" ! -name "$itemDefinitionFileName" ! -name "$itemConfigFileName")
        if [ -n "$contentFiles" ]; then
            echo "Found $(echo "$contentFiles" | wc -l) content file(s) for $(echo "$itemMetadata" | jq -r '.displayName')"
            for part in $(echo "$itemDefinition" | jq -r '.definition.parts[] | @base64'); do
                part=$(echo "$part" | base64 --decode)
                file=$(echo "$contentFiles" | grep "$(echo "$part" | jq -r '.path')")
                itemContent=$(cat "$file")
                base64Content=$(echo -n "$itemContent" | base64)
                part=$(echo "$part" | jq --arg payload "$base64Content" '.payload = $payload')
                itemDefinition=$(echo "$itemDefinition" | jq --argjson part "$part" '.definition.parts |= map(if .path == $part.path then $part else . end)')
            done
            echo "$itemDefinition" | jq '.' > "$definitionFilePath"
            echo "Updated item definition payload with content file for $(echo "$itemMetadata" | jq -r '.displayName')"
        else
            echo "Missing content file or found more than one content file, skipping update definition for $folder."
            return
        fi
    fi

    configFilePath="$folder/$itemConfigFileName"
    if [ ! -f "$configFilePath" ] || [ "$resetConfig" == "true" ]; then
        echo "No $itemConfigFileName file found, creating new file."
        itemConfig=$(jq -n --arg logicalId "$(uuidgen)" '{logicalId: $logicalId}')
        echo "$itemConfig" | jq '.' > "$configFilePath"
    else
        itemConfig=$(cat "$configFilePath")
        echo "Found item config file for $folder. Item missing objectId? $(echo "$itemConfig" | jq -r 'has("objectId") | not'). Item missing logicalId? $(echo "$itemConfig" | jq -r 'has("logicalId") | not')"
    fi

    if [ -z "$(echo "$itemConfig" | jq -r '.objectId')" ]; then
        echo "Item $folder does not have an associated objectId, creating new Fabric item of type $(echo "$itemMetadata" | jq -r '.type') with name $(echo "$itemMetadata" | jq -r '.displayName')."
        item=$(create_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition")
        itemConfig=$(echo "$itemConfig" | jq --arg objectId "$(echo "$item" | jq -r '.id')" '.objectId = $objectId')
        echo "$itemConfig" | jq '.' > "$configFilePath"
        repoItems+=("$(echo "$item" | jq -r '.id')")
    else
        item=$(echo "$workspaceItems" | jq -r ".[] | select(.id == \"$(echo "$itemConfig" | jq -r '.objectId')\")")
        if [ -z "$item" ]; then
            echo "Item $(echo "$itemConfig" | jq -r '.objectId') of type $(echo "$itemMetadata" | jq -r '.type') was not found in the workspace, creating new item."
            item=$(create_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition")
            itemConfig=$(echo "$itemConfig" | jq --arg objectId "$(echo "$item" | jq -r '.id')" '.objectId = $objectId')
            echo "$itemConfig" | jq '.' > "$configFilePath"
            repoItems+=("$(echo "$item" | jq -r '.id')")
        else
            repoItems+=("$(echo "$itemConfig" | jq -r '.objectId')")
            echo "Item $(echo "$itemConfig" | jq -r '.objectId') of type $(echo "$item" | jq -r '.type') was found in the workspace, updating item."
            update_workspace_item "$baseUrl" "$workspace_id" "$requestHeader" "$contentType" "$itemMetadata" "$itemDefinition" "$itemConfig"
        fi
    fi
    echo "${repoItems[@]}"
}