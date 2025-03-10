# Simplified Update Item Script – Usage Instructions

## Overview
The `simplified_update_item.sh` script is part of our Fabric Git integration workflow. It is designed to:
- Authenticate with the Fabric API (refreshing the API token if expired).
- Retrieve a specific workspace by name.
- Locate an item within that workspace by its name and type.
- Download the item's definition (or metadata if the item type does not support definition retrieval).
- Save the definition files locally for further processing (e.g., version control, CI/CD).

## Prerequisite Software
- **Bash**: The script is written in Bash and requires a Unix-like shell.
- **Azure CLI (az)**: Used by the helper functions to make REST API calls to Fabric.
- **jq**: For processing JSON responses.
- **curl**: For HTTP requests made in the long-running operations.
- **Git**: To manage your repository.
- A proper configuration file located at `./config/.env` containing the following variables:
    - `TENANT_ID`: Required. Your Entra Tenant ID, used to authenticate and retrieve an access token
    - `FABRIC_API_BASEURL`: Required. The base URL for the Fabric API.
    - `FABRIC_USER_TOKEN`: Optional. The authentication token for the Fabric API. This will be filled by the script, can be left as is.

    > Note: The Fabric Capacity needs to be running, else the script will fail 

## Assumptions

The sample assumes the following:
- the script should be executed using a user that has access to the Fabric workspace for which items need to be downloaded, with minimal permisions of `Viewer`.
- The Fabric workspace from which items should be downloaded is assigned to a running Fabric capacity. If the capacity is paused the script will fail.


## How to Use the Script
1. **Ensure Environment Setup:**
   - Verify that all the prerequisite software is installed and available in your system’s PATH.
   - Create a copy of the [`.envtemplate`](../config/.envtemplate) file and rename it to `.env`
   ```bash
   cp ./config/.envtemplate ./config/.env
   ```
   - Edit the newly created `.env` file, filling the required parameters (`TENANT_ID`, `FABRIC_API_BASEURL`)
   - Confirm that your `./config/.env` file is up to date with the correct Fabric API endpoint and token.
   - Load environment variables
   ```bash
   source config/.env
   ```
   - Login to Azure CLI with your user or SPN/MI, below instructions for user login with device code:
   ```bash
   az login --use-device-code
   ```

2. **Script Parameters:**
   The script requires four parameters:
   - **workspaceName**: The display name of the Fabric workspace.
   - **itemName**: The name of the Fabric item to retrieve.
   - **itemType**: The type of the Fabric item (e.g., Notebook, DataPipeline) used to disambiguate items with the same name.
   - **folder**: The local destination folder in your filesystem (local repository) where the retrieved item definition (or metadata) will be stored.

3. **Example Usage:**
   ```bash
   ./src/simplified_update_item.sh "MyWorkspaceName" "MyNotebookName" "Notebook" "./fabric"
   ```
   This command will:
   - Check if the Fabric API token is expired; if so, it will refresh the token and reload environment variables.
   - Retrieve the workspace ID corresponding to `MyWorkspaceName`.
   - Look for the item `MyNotebookName` of type `Notebook` within that workspace. Revie the list of supported [Fabric item types](https://learn.microsoft.com/rest/api/fabric/core/items/list-items?tabs=HTTP#itemtype).
   - Download the item definition and store the resulting files in the `./fabric` folder.

4. **Commit to source control**
   - **Manual Step**: After the item definition is downloaded locally, the files can be committed to the feature branch with the preferred mechanism: for example using VS Code or by executing a `git commit` command.


## Troubleshooting
- If the script cannot find the workspace or item, double-check the names and types.
- Ensure that the right Tenant ID is provided. The script will attempt to refresh expired tokens automatically.
- Verify that the necessary tools (az, jq, curl, git) are installed and accessible.