# Fabric CI/CD Sample for Multi-Tenancy or Generic Git

## Introduction
The code in this sample showcases ways to mimic the Microsoft Fabric [Git Integration](https://learn.microsoft.com/fabric/cicd/git-integration/intro-to-git-integration?tabs=azure-devops) functionality, accommodating multi-tenancy and generic-git deployments for currently unsupported scenarios. While the sample currently has some [limitations](#known-limitations), the goal is to iteratively enhance its capabilities in alignment with Fabric’s advancements.

This sample is recommended if:

- Your organization adopts multi-tenancy in their CI/CD processes where different environments (such as Development, Staging, and Production) are on different Microsoft Entra IDs.
- Your organization's preferred git provider is not yet supported by Microsoft Fabric (e.g. GitLab, Bitbucket). For more details, review the list of [supported Git providers](https://learn.microsoft.com/fabric/cicd/git-integration/intro-to-git-integration?tabs=azure-devops).

If none of the scenarios above match your current situation, consider using the [Fabric CI/CD sample for Azure DevOps](../fabric_ci_cd/README.md).

## Contents of This Sample
This sample showcases two approaches:
- A simplified way for tracking Microsoft Fabric items with source control.
- A more advanced example attempting to provide a comprehensive solution for CI/CD in unsupported scenarios.

### Simplified Approach
The simplified approach is suited for scenarios where multiple developers might be working on the same Fabric workspace and need to selectively download and store their work in source control, one Fabric item at a time.

If you are interested in this approach, follow the [instruction for the simplified approach](./docs/simplified_approach.md).

### Comprehensive Approach
The comprehensive approach is suited for scenarios where each developer is working on different workspaces, and it is acceptable to have a one-to-one mapping between feature branches and Fabric workspaces.

If you are interested in this approach, follow the [instruction for the comprehensive approach](./docs/full_cicd_approach.md).

## Known limitations

- Microsoft Information Protection labels are enforced by Fabric but there is still not a way to set MIP labels via APIs. When MIP labels are defaulting to Restricted/Confidential, then some of the API calls in the below scripts might fail.
- Service Principal authentication is currently not supported by Fabric APIs (See [Microsoft Documentation](https://learn.microsoft.com/rest/api/fabric/articles/using-fabric-apis#considerations-and-limitation)), therefore this sample is currently relying on user tokens. See the below instructions for generating a valid user token.

### Generating a Fabric Bearer Token

Service Principal and Managed Identity Authentication is currently supported by some Fabric REST APIs. When such authentication is not available, REST APIs need to be executed with user context, using a user token. Such user token is valid for one hour and needs to be refreshed after that. There are several ways to generate the token:

- **(Recommended) Using a bash script**: Using the [`refresh_api_token.sh`](./src/refresh_api_token.sh) bash script. This script also supports generating the token with SPN/MI Authentication, using the `use_spn` parameter.
    ```bash
    ./src/refresh_api_token.sh
    ```

- **Using PowerShell**: The token can be generated by using the following PowerShell command:

    ```powershell
    [PS]> Connect-PowerBIServiceAccount
    [PS]> Get-PowerBIAccessToken
    ```

- **Using Edge browser devtools (F12)**: If you are already logged into Fabric portal, you can invoke the following command from the Edge Browser DevTools (F12) console:

    ```sh
    > copy(PowerBIAccessToken)
    ```

    This will copy the token to your clipboard. You can then paste its value in the `params.psd1` file.

## Roadmap

- Triggering hydration of Lakehouse (via Data Pipelines and Notebook).
