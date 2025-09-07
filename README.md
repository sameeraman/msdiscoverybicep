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
| `discovery_midentity_template.bicep` | Subscription‑scope template creating a User Assigned Managed Identity (UAMI) and role assignments. This also create the resource group|
| `discovery_infra_template.bicep`  | Core infrastructure (VNet, Storage Account, Discovery resources: storage, supercomputer, nodepool, workspace, RBAC). |
| `discovery_agent_workflow_bookshelf_template.bicep` | Deploys Microsoft Discovery Agent, Workflow and Bookshelf resources. Supports file‑based definition + inline override. |
| `definitions/` | Example Microsoft Discovery agent & workflow JSON definition files used as defaults. |

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

These steps are also available in the [deployment.sh](/deployment.sh) file. 

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

This step provisions the resource group and the managed identity in it. 

You will see the deployment status as below. 

![Deployment Steps](/images/SCR-20250907-jpzq.png)

![Deployment Steps](/images/SCR-20250907-iult.png)

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

This step provisions the Virtual Network, Storage Account and other Microsoft Discovery Resources. 

You will see the deployment status as below. 

![Deployment Steps](/images/SCR-20250907-jqcl.png)

Once the resources are deployed succesfully, you will see the resources as below. 

![Deployment Steps](/images/SCR-20250906-mdxa.png)

### 5. Deploy Microsoft Discovery Agent, Workflow and the Bookshelf
```bash
az deployment group create \
  --name $deploymentName-ag-wf-bs-deploy \
  --resource-group $rgName \
  --template-file discovery_agent_workflow_bookshelf_template.bicep  \
  --parameters @discovery_agent_workflow_bookshelf_template.parameters.json location=$location
```
This step refer's to the [agent](/definitions/example-agent-definition.json) and [workflow](/definitions/example-workflow-definition.json) definition files located in the [definitions folder](/definitions/).

You will the deployment status as below. 

![step3 deployment status](/images/SCR-20250907-jtik.png)

You will see the Agent, Workflow and the Bookshelf resources successfully provisioned as below. 

![step3 resources](/images/SCR-20250907-jtpg.png)

You will see the management resource groups as below. 

![management resource groups](/images/SCR-20250907-jtvv.png)



