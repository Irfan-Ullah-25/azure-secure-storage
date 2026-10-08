# Azure Secure Storage Platform with Terraform

## 1. Project Overview

This project provisions a secure internal Azure storage platform using Terraform.

The infrastructure is designed with a **private-by-default security model**. Application storage and Key Vault are not publicly accessible and are accessed through Azure Private Endpoints and Private DNS.

The project also implements a GitHub Actions CI/CD pipeline using **OIDC / Workload Identity Federation**, eliminating the need to store long-lived Azure client secrets in GitHub.

### Main objectives

* Deploy reusable Azure infrastructure with Terraform
* Secure Azure Storage using Private Endpoint
* Disable public network access to application storage
* Configure Private DNS for private name resolution
* Secure Azure Key Vault using RBAC and Private Endpoint
* Create a least-privilege User-Assigned Managed Identity
* Store Terraform state remotely in Azure Blob Storage
* Separate development and production environments
* Implement Terraform validation and security scanning
* Authenticate GitHub Actions to Azure using OIDC
* Require manual approval before production deployment

---

# 2. Architecture

```text
                         GitHub
                            │
                            │ OIDC
                            ▼
                  Microsoft Entra ID
                            │
                  Workload Identity
                    Federation
                            │
                            ▼
                  Production Service
                      Principal
                            │
                    Azure RBAC
                            │
                            ▼
                    Azure Subscription
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
              VNet                  Key Vault
                 │                Private Endpoint
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
 Workload Subnet    Private Endpoint
                    Subnet
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
       Storage Account          Key Vault
       Public Access: OFF      Public Access: OFF
              │
       Private Endpoint
              │
              ▼
       Private DNS Zone
privatelink.blob.core.windows.net
```

---

# 3. Repository Structure

```text
azure-secure-storage/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── dev.tfvars
│   │
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── versions.tf
│       └── prod.tfvars
│
├── modules/
│   ├── networking/
│   ├── storage/
│   ├── key-vault/
│   └── identity/
│
├── .gitignore
└── versions.tf
```

### Why this structure?

The infrastructure is separated into **reusable modules** so that common components can be reused across environments.

The `dev` and `prod` directories provide environment isolation while using the same underlying modules.

This avoids duplicating infrastructure code and makes future changes easier to manage.

---

# 4. Prerequisites

Install the following tools:

* Terraform >= 1.6
* Azure CLI
* Git
* GitHub account/repository
* An Azure subscription

Verify installations:

```bash
terraform version
az version
git --version
```

Authenticate to Azure:

```bash
az login
```

Select the required subscription:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

---

# 5. Terraform Backend

Terraform state is stored remotely in Azure Blob Storage.

The backend uses:

```text
Resource Group:
rg-tfstate-dev

Storage Account:
tfstateauctiondev

Container:
tfstate
```

Development state:

```text
azure-secure-storage.tfstate
```

Production state:

```text
azure-secure-storage-prod.tfstate
```

Using separate state keys prevents development and production state from being mixed.

The Azure Blob backend also provides state locking using Azure Blob lease mechanisms, helping prevent concurrent Terraform operations from modifying the same state.

---

# 6. Deploy Development Environment

Navigate to the development environment:

```bash
cd environments/dev
```

Initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt -recursive
```

Validate the configuration:

```bash
terraform validate
```

Review the deployment plan:

```bash
terraform plan \
  -var-file=dev.tfvars
```

Apply the infrastructure:

```bash
terraform apply \
  -var-file=dev.tfvars
```

After deployment, view outputs:

```bash
terraform output
```

---

# 7. Deploy Production Environment

Production uses the same reusable Terraform modules but has separate configuration and state.

Navigate to:

```bash
cd environments/prod
```

Initialize Terraform:

```bash
terraform init
```

Validate:

```bash
terraform validate
```

Create a production plan:

```bash
terraform plan \
  -var-file=prod.tfvars
```

Production should normally be deployed through the GitHub Actions pipeline after the required approval.

Manual deployment should only be used when explicitly required:

```bash
terraform apply \
  -var-file=prod.tfvars
```

---

# 8. Networking Design

The VNet uses separate subnets for workloads and Private Endpoints.

Development example:

```text
VNet
10.10.0.0/16
│
├── Workload subnet
│   10.10.1.0/24
│
└── Private Endpoint subnet
    10.10.2.0/24
```

Production uses a separate address space:

```text
VNet
10.20.0.0/16
│
├── Workload subnet
│   10.20.1.0/24
│
└── Private Endpoint subnet
    10.20.2.0/24
```

Network Security Groups are associated with the subnets.

---

# 9. Storage Security

The application Storage Account is configured with:

* Public network access disabled
* HTTPS-only traffic
* TLS 1.2 minimum
* Shared access keys disabled
* OAuth as the default authentication method
* Local users disabled
* Public nested items disabled
* Blob versioning enabled
* Blob deletion retention enabled
* Container deletion retention enabled
* SAS expiration policy
* Private Endpoint
* Private DNS

The Storage Account therefore does not depend on public network access.

---

# 10. Private DNS

The Blob Private Endpoint uses:

```text
privatelink.blob.core.windows.net
```

The Private DNS zone is linked to the VNet.

This allows the normal Azure Storage hostname to resolve to the private endpoint IP from within the VNet.

Conceptually:

```text
Storage hostname
        │
        ▼
Private DNS
        │
        ▼
Private Endpoint IP
        │
        ▼
Storage Account
```

---

# 11. Key Vault Security

Azure Key Vault is configured with:

* RBAC authorization
* Public network access disabled
* Network ACL default action: Deny
* Private Endpoint
* Private DNS
* Soft delete
* Purge protection

RBAC is used instead of legacy access policies so that access can be managed consistently through Azure role assignments.

---

# 12. Managed Identity and Least Privilege

A User-Assigned Managed Identity is created for application workloads.

The identity receives only:

```text
Storage Blob Data Reader
```

at the application Storage Account scope.

This allows the workload to:

* Read blob data
* List permitted blob resources

It does not allow the workload to:

* Upload blobs
* Delete blobs
* Modify storage configuration
* Create storage accounts
* Manage RBAC permissions

The purpose is to follow the **principle of least privilege**.

Applications can use the Managed Identity instead of storing storage account credentials in application configuration.

---

# 13. CI/CD Pipeline

GitHub Actions is used for Terraform CI/CD.

The pipeline performs:

```text
Pull Request
     │
     ├── terraform fmt
     ├── terraform validate
     ├── Checkov security scan
     └── terraform plan
             │
             ▼
        Review Plan
```

After changes are merged to `main`:

```text
main
 │
 ├── Terraform Plan
 │
 ▼
Production Environment Approval
 │
 ▼
Terraform Apply
```

The Terraform plan output is published in the GitHub Actions job summary so reviewers can inspect the proposed infrastructure changes.

---

# 14. Azure Authentication with OIDC

The GitHub Actions pipeline does not store an Azure client secret.

Instead, it uses:

**OpenID Connect (OIDC)** and **Microsoft Entra Workload Identity Federation**.

The authentication flow is:

```text
GitHub Actions
      │
      │ Short-lived OIDC token
      ▼
Microsoft Entra ID
      │
      │ Federated Identity Credential
      ▼
Azure Service Principal
      │
      │ Azure RBAC
      ▼
Azure Resources
```

The trusted GitHub repository and deployment context are configured using Federated Identity Credentials.

This removes the need for long-lived client secrets in GitHub.

---

# 15. Production Service Principal Permissions

The production Service Principal has:

```text
Contributor
User Access Administrator
```

### Contributor

Allows Terraform to manage Azure resources such as:

* Resource Groups
* VNets
* Subnets
* Storage Accounts
* Key Vault
* Private Endpoints

### User Access Administrator

Allows Terraform to manage Azure RBAC assignments.

This is required because the Terraform configuration creates a role assignment for the User-Assigned Managed Identity.

The separation of responsibilities is:

```text
Service Principal
       │
       ├── Contributor
       │     └── Manage Azure resources
       │
       └── User Access Administrator
             └── Manage RBAC assignments
```

---

# 16. Security Scanning

Checkov is executed during CI.

The purpose is to identify common Terraform security and compliance issues before infrastructure is deployed.

The pipeline performs:

```bash
terraform fmt -check -recursive
```

```bash
terraform validate
```

and a Checkov Terraform security scan.

Security checks that are not applicable to this architecture are explicitly documented/skipped rather than silently ignored.

---

# 17. Production Improvements

The following improvements could be implemented for a larger production environment:

### Terraform State Security

The Terraform backend could be further hardened with:

* Private Endpoint
* Private DNS
* Restricted network access
* Separate state subscription/resource group where appropriate
* Storage firewall rules
* Diagnostic logging

### CI/CD Permissions

The production Service Principal could be reduced from broad subscription-level permissions to more narrowly scoped permissions where practical.

### Azure Policy

Azure Policy could enforce:

* No public Storage Accounts
* TLS 1.2+
* Required tags
* Private Endpoints
* Approved Azure regions
* Encryption requirements

### Monitoring

Add:

* Azure Monitor
* Log Analytics
* Storage diagnostic settings
* Key Vault diagnostic settings
* Microsoft Defender for Cloud

### Terraform

Additional improvements could include:

* Remote state encryption and additional controls
* Module versioning
* Automated dependency updates
* Terraform documentation generation
* Policy-as-code
* Drift detection
* Separate Azure subscriptions for development and production

### Application Security

For workloads using the Managed Identity:

* Run containers as non-root
* Use resource limits
* Use private AKS/compute where appropriate
* Use image scanning
* Pin container images by digest
* Avoid storing credentials in application configuration

---

# 18. Assumptions

The following assumptions were made:

1. The Azure subscription is controlled by the project owner.
2. Azure region `eastus` is used for the example deployment.
3. Development and production use separate Terraform state keys.
4. Application storage is required to be private and accessed through Private Endpoint.
5. The User-Assigned Managed Identity is intended for an Azure workload that requires read-only Blob access.
6. Production deployments require GitHub environment approval.
7. No real company credentials, secrets, or sensitive production information are stored in the repository.

---

# 19. Summary

This project demonstrates a secure Terraform-based Azure infrastructure design with:

* Reusable Terraform modules
* Separate development and production environments
* Remote Terraform state
* State locking
* Azure VNet and subnet segmentation
* Network Security Groups
* Private Storage Account
* Storage Private Endpoint
* Private DNS
* Private Key Vault
* RBAC-based Key Vault authorization
* User-Assigned Managed Identity
* Least-privilege Blob access
* Terraform security scanning
* GitHub Actions CI/CD
* OIDC authentication
* Workload Identity Federation
* Production approval before Terraform Apply

The overall design follows the principles of **least privilege, private-by-default networking, infrastructure as code, environment separation, and secretless CI/CD authentication**.

