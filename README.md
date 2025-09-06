# Microsoft Discovery Infrastructure Deployment

This repository provides Bicep templates and a deployment script to automate the provisioning of Microsoft Discovery Infrastructure resources in Azure. For more information about Microsoft Discovery please see this [blog](https://azure.microsoft.com/en-us/blog/transforming-rd-with-agentic-ai-introducing-microsoft-discovery/). Follow this guide to deploy all required components, including managed identity, storage, networking, supercomputer, workspace, agent, and workflow resources.

## Prerequisites

- An **active Azure subscription** with Microsoft Discovery enabled.
- **Owner** permissions in your Azure subscription.
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed and logged in.
- Sufficient quotas for compute, storage, and AI resources in your target region.

## Overview of Deployment Steps

1. Register Azure Resource Providers
2. Assign Required Admin Roles
3. Deploy Managed Identity & Resource Group
4. Deploy Core Infrastructure Resources
   1. Storage account (and blob container + CORS + RBAC)
   2. Virtual network & subnets
   3. Microsoft Discovery Storage resource (preview) and permissions
   4. Microsoft Discovery Supercomputer + Nodepool (preview)
   5. Microsoft Discovery Workspace (preview)
5. Deploy Microsoft Discovery Agent
6. Deploy Microsoft Discovery Workflow

High level deployment steps are below. 
![Deployment Steps](/images/bicep_deployment_flow.png)

## Repository Structure
| File / Folder | Purpose |
|---------------|---------|
| `deployment.sh` | Details the end‑to‑end deployment commands (registration, RBAC, infra, agent, workflow). |
| `discovery-midentity.bicep` | Subscription‑scope template creating a User Assigned Managed Identity (UAMI) and role assignments. This also create the resource group|
| `discovery_infra_template.bicep`  | Core infrastructure (VNet, Storage Account, Discovery resources: storage, supercomputer, nodepool, workspace, RBAC). |
| `discovery_agent_template.bicep` | Deploys a Discovery Agent. Supports file‑based definition + inline override. |
| `discovery_workflow_template.bicep` | Deploys a Discovery Workflow. Supports file‑based definition + inline override. |
| `definitions/` | Example agent & workflow JSON definition files used as defaults. |

## Prerequisites
1. Azure CLI v2.60+ (`az version`).
2. Logged in & correct subscription selected:
   ```bash
   az login
   az account set --subscription <SUBSCRIPTION_ID>
   ```
3. Register required resource providers (script already does this, but you can pre‑run):
   ```bash
    for ns in Microsoft.Discovery Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.ManagedIdentity Microsoft.AlertsManagement Microsoft.Authorization Microsoft.CognitiveServices Microsoft.ContainerInstance Microsoft.ContainerRegistry Microsoft.ContainerService Microsoft.DocumentDB Microsoft.Features Microsoft.KeyVault Microsoft.MachineLearningServices Microsoft.NetApp Microsoft.OperationalInsights Microsoft.ResourceGraph Microsoft.Search Microsoft.Web Microsoft.Insights Microsoft.Resources Microsoft.Sql Microsoft.App; do
        echo "Registering $ns..."
        az provider register -n "$ns" --only-show-errors >/dev/null || echo "Failed: $ns"
    done
   ```
4. Validate resource provider registrations.
   ```bash
    for p in Microsoft.Discovery Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.ManagedIdentity Microsoft.AlertsManagement Microsoft.Authorization Microsoft.CognitiveServices Microsoft.ContainerInstance Microsoft.ContainerRegistry Microsoft.ContainerService Microsoft.DocumentDB Microsoft.Features Microsoft.KeyVault Microsoft.MachineLearningServices Microsoft.NetApp Microsoft.OperationalInsights Microsoft.ResourceGraph Microsoft.Search Microsoft.Web Microsoft.Insights Microsoft.Resources Microsoft.Sql Microsoft.App; do
        az provider show --namespace "$p" --query "{Provider:namespace,State:registrationState}" -o table
    done
   ```
5. Sufficient permissions (Owner or User Access Administrator + Role Assignment rights) to create identities and assign roles at subscription scope.

## Manual Step‑By‑Step

> Preview Notice: `Microsoft.Discovery/*` resource types are in preview (`2025-07-01-preview`). The Azure Resource Provider (RP) may change; schema validation in Bicep shows warnings (`BCP081`) because type definitions are not yet published. These warnings are non‑blocking.

### 1. Define the variables for the deployment:
```bash
rgName=ai-eus2-npe-arg-sp5                              # Resource group name
mIdentityName=msdisc5-mi                                # management identity resource name, I noted that MI name has to be less than 10 characters for the deployment to be successful. 
deploymentName=disc5-eus2                               # Deployment name less than 10 characters
location=eastus2
subscriptionId=<your-subscription-guid>
adminuser=<aad-upn-or-object-id>
```

If you need to update the individual resource names, you can update them in each of the `parameters.json` files 

### 2. Assign the roles to the admin user (Needs to be done only once at the subscription level)
Assign the following roles to the user account who will conduct the deployment. 
```bash
# Create Microsoft Discovery Platform Administrator role assignment
az role assignment create --assignee $adminuser --role "7a2b6e6c-472e-4b39-8878-a26eb63d75c6" --scope /subscriptions/$subscriptionId

# Microsoft Discovery Platform Contributor role assignment
az role assignment create --assignee $adminuser --role "01288891-85ee-45a7-b367-9db3b752fc65" --scope /subscriptions/$subscriptionId
```


### 3. Create Resource Group & Identity
```bash
az deployment sub create \
  --name  $deploymentName-uami-deploy \
  --location $location \
  --template-file discovery_midentity_template.bicep \
  --parameters @discovery_midentity_template.parameters.json mIdentityName=$mIdentityName resourceGroupName=$rgName location=$location
```
### 4. Deploy Core Infrastructure
```bash
az deployment group create \
  --name $deploymentName-infra-deploy \
  --resource-group $rgName  \
  --template-file discovery_infra_template.bicep \
  --parameters @discovery_infra_template.parameters.json deploymentName=$deploymentName mIdentityName=$mIdentityName location=$location 
```

You can update parameter values in the parameters file or override them inline (later values win):

You can add `--debug` option to the deployment command if the deployment error's out to get additional information. 

### 5. Deploy Microsoft Discovery Agent
```bash
az deployment group create \
  --name $deploymentName-agent-deploy \
  --resource-group $rgName \
  --template-file discovery_agent_template.bicep \
  --parameters @discovery_agent_template.parameters.json location=$location 

```

### 6. Deploy Microsoft Discovery Workflow
```bash
az deployment group create \
  --name $deploymentName-workflow-deploy \
  --resource-group $rgName \
  --template-file discovery_workflow_template.bicep \
  --parameters @discovery_workflow_template.parameters.json location=$location
```



