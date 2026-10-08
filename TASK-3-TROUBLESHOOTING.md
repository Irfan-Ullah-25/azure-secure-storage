# Task 3 — Production Troubleshooting

## Scenario 1 — Application returns HTTP 500 only in Production

The application works in Dev, QA, and UAT, and the code is identical. Since the failure starts immediately after the production release, I would first investigate production-specific configuration, dependencies, and runtime differences.

### Troubleshooting steps

1. **Confirm the incident and scope**

   * Check the application's HTTP status, affected endpoints, start time, and whether all users are affected.
   * Check monitoring/APM tools such as Azure Monitor, Application Insights, Grafana, or Prometheus.

2. **Check application logs**

   ```bash
   kubectl logs deployment/<deployment-name> -n <namespace> --tail=200
   ```

   * Look for exceptions, database connection failures, authentication errors, missing environment variables, or dependency failures.

3. **Check Pod status and recent events**

   ```bash
   kubectl get pods -n <namespace>
   kubectl describe pod <pod-name> -n <namespace>
   kubectl get events -n <namespace> --sort-by=.lastTimestamp
   ```

   * This helps identify restarts, failed probes, configuration problems, or resource issues.

4. **Compare production configuration with Dev/QA/UAT**

   * Compare environment variables, ConfigMaps, Secrets, feature flags, API URLs, database connection strings, and credentials.

   ```bash
   kubectl get configmap -n <namespace>
   kubectl get secret -n <namespace>
   ```

   * I would not print secret values into logs or the terminal unnecessarily.

5. **Check production dependencies**

   * Verify database connectivity, DNS resolution, external APIs, Key Vault access, storage access, and authentication.

   ```bash
   kubectl exec -it <pod-name> -n <namespace> -- nslookup <database-host>
   ```

   * Test connectivity to the required dependency from the same runtime environment.

6. **Check the production deployment**

   ```bash
   kubectl rollout status deployment/<deployment-name> -n <namespace>
   kubectl rollout history deployment/<deployment-name> -n <namespace>
   ```

   * Confirm that the expected image/version and configuration were deployed.

7. **Check recent changes**

   * Compare the production deployment with the last known-good version.
   * Review deployment, Terraform, Helm, ConfigMap, Secret, and infrastructure changes.

8. **Rollback if the release is confirmed as the cause**

   ```bash
   kubectl rollout undo deployment/<deployment-name> -n <namespace>
   kubectl rollout status deployment/<deployment-name> -n <namespace>
   ```

   * Rollback restores service while the root cause is investigated.

9. **Verify recovery**

   ```bash
   kubectl get pods -n <namespace>
   kubectl get svc -n <namespace>
   ```

   * Confirm HTTP 500 errors have stopped and the application's health checks are passing.

---

## Scenario 2 — Corrupted Terraform State

The important rule is **do not immediately run `terraform apply` again**. The Azure resources still exist, but Terraform's state no longer correctly represents them.

### Troubleshooting steps

1. **Stop concurrent Terraform operations**

   * Ask other engineers not to run Terraform against the affected production state.
   * This prevents further state divergence.

2. **Back up the current state**

   * If using an Azure Blob backend, preserve the existing state and investigate the backend/version history.
   * If a local state copy is available, create a backup before making changes.

3. **Inspect the current state**

   ```bash
   terraform state list
   terraform state pull > corrupted-state-backup.json
   ```

   * Determine which resources Terraform still knows about.

4. **Compare Terraform state with Azure**

   ```bash
   az resource list --resource-group <resource-group>
   ```

   * Identify resources that exist in Azure but are missing from Terraform state.

5. **Check the Terraform configuration**

   ```bash
   terraform init
   terraform validate
   terraform plan
   ```

   * Do not blindly apply the plan. First determine why Terraform believes the resources are missing.

6. **Recover the state if a known-good backup exists**

   * Restore the most recent valid state according to the organization's recovery procedure.
   * With an Azure Storage backend, check blob versioning/backups if configured.

7. **If recovery is not possible, import existing Azure resources**

   ```bash
   terraform import <resource-address> <azure-resource-id>
   ```

   * Import each existing resource that should be managed by Terraform.

8. **Verify the reconstructed state**

   ```bash
   terraform state list
   terraform plan
   ```

   * The goal is for the plan to show no unexpected recreation or destruction.

9. **Review the plan carefully**

   * Pay particular attention to resources involving networking, storage, databases, identities, and production data.
   * Do not accept a plan that proposes destructive changes until the state/configuration mismatch is understood.

10. **Resume deployments only after verification**

* Once the state is consistent with Azure and the plan is reviewed, allow other engineers to continue deploying.

**Key principle:** State recovery comes before another production apply. Recreating resources simply because they are missing from state could cause outages or data loss.

---

## Scenario 3 — AKS is four Kubernetes minor versions behind

I would not immediately force an unsupported upgrade. First I would determine which upgrade paths Azure currently supports for the specific AKS cluster.

### Troubleshooting steps

1. **Check the current cluster version**

   ```bash
   az aks show \
     --resource-group <resource-group> \
     --name <cluster-name> \
     --query kubernetesVersion \
     -o tsv
   ```

2. **Check available AKS versions**

   ```bash
   az aks get-upgrades \
     --resource-group <resource-group> \
     --name <cluster-name> \
     -o table
   ```

   * This shows the upgrade versions currently offered for the cluster.

3. **Check Azure support/lifecycle information**

   * Determine whether the current Kubernetes version is still supported.
   * Confirm the supported upgrade path for the cluster's region and AKS configuration.

4. **Do not attempt to jump through unsupported versions**

   * If the normal sequential upgrade targets are no longer offered, I would not repeatedly try arbitrary `az aks upgrade` commands.
   * An unsupported upgrade can cause operational problems.

5. **Review cluster dependencies before upgrading**

   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl get deployments -A
   kubectl get statefulsets -A
   ```

   * Check workloads, operators, ingress controllers, CSI drivers, admission controllers, and other Kubernetes-dependent components.

6. **Check API compatibility**

   * Review deprecated/removed Kubernetes APIs used by the workloads.
   * Validate Helm charts and manifests against the target Kubernetes version.

7. **Test the upgrade path**

   * Use a non-production AKS cluster or staging environment with a similar configuration.
   * Upgrade and verify applications, networking, storage, ingress, autoscaling, and monitoring.

8. **If the current cluster cannot directly reach a supported version**

   * Follow Azure's documented recovery/upgrade path for that AKS version and cluster state.
   * If necessary, create a new supported AKS cluster and migrate workloads using a controlled blue/green or migration strategy.

9. **Back up critical workloads/data**

   * Ensure databases, persistent volumes, and application configuration have appropriate backups before making major cluster changes.

10. **Perform the production upgrade during a maintenance window**

* Monitor node health, workload availability, ingress, storage, and application metrics throughout the upgrade.

11. **Verify after the upgrade**

```bash
az aks show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query kubernetesVersion \
  -o tsv

kubectl get nodes
kubectl get pods -A
```

**Key principle:** I would follow the currently supported AKS upgrade path rather than forcing an unsupported multi-version jump.

---

## Scenario 4 — Self-hosted runner cannot reach a Private Endpoint

A connection timeout strongly suggests a network path, DNS, routing, firewall/NSG, or private endpoint problem. I would troubleshoot from the runner itself because that is where the connection fails.

### Troubleshooting steps

1. **Identify where the runner is located**

   * Determine whether it is an Azure VM, on-premises server, another cloud, or another VNet.
   * Confirm which VNet/subnet the runner uses.

2. **Test DNS resolution from the runner**

   ```bash
   nslookup <storage-account-name>.blob.core.windows.net
   ```

   or:

   ```bash
   dig <storage-account-name>.blob.core.windows.net
   ```

   * The storage hostname should resolve to the Private Endpoint's private IP when accessed from the correct network.

3. **Check the Private Endpoint**

   ```bash
   az network private-endpoint show \
     --resource-group <resource-group> \
     --name <private-endpoint-name>
   ```

   * Verify that the Private Endpoint connection is approved and connected.

4. **Find the Private Endpoint IP**

   ```bash
   az network private-endpoint show \
     --resource-group <resource-group> \
     --name <private-endpoint-name> \
     --query "customDnsConfigs"
   ```

5. **Test network connectivity**

   ```bash
   nc -vz <private-endpoint-ip> 443
   ```

   or:

   ```bash
   curl -v https://<storage-account-name>.blob.core.windows.net
   ```

   * If DNS is correct but port 443 times out, investigate routing and firewall controls.

6. **Check Private DNS**

   * Verify that the Private DNS zone exists:

   ```bash
   az network private-dns zone show \
     --resource-group <resource-group> \
     --name privatelink.blob.core.windows.net
   ```

   * Verify that the runner's VNet is linked to the Private DNS zone.

7. **Check VNet routing**

   * Verify that the runner has a route to the Private Endpoint subnet/IP.
   * If the runner is on-premises, verify VPN/ExpressRoute connectivity and routing to Azure.

8. **Check NSGs and firewall rules**

   * Verify that outbound TCP/443 is allowed from the runner.
   * Check NSGs, Azure Firewall, NVA rules, route tables, and any on-premises firewall.

9. **Check the Storage Account networking configuration**

   ```bash
   az storage account show \
     --name <storage-account-name> \
     --resource-group <resource-group> \
     --query "{publicNetworkAccess:publicNetworkAccess,defaultAction:networkRuleSet.defaultAction}"
   ```

   * Confirm that the intended Private Endpoint/network path is being used.

10. **Use Azure Network Watcher if available**

* Use connection troubleshooting to identify whether traffic is blocked by routing, NSG, or another network component.

11. **Retest from the pipeline runner**

```bash
curl -v https://<storage-account-name>.blob.core.windows.net
```

12. **Only after connectivity works, troubleshoot authentication**

* If the timeout changes to an authentication/authorization error, then investigate the runner's identity, RBAC permissions, or storage authentication.
* A timeout is primarily a connectivity problem, not an RBAC problem.

**Key principle:** For a Private Endpoint timeout, troubleshoot in this order: **DNS → private IP → routing → NSG/firewall → Private Endpoint state → authentication**.

