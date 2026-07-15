# Voyager Testing Guide and Evaluation Answers

This guide contains the evaluation criteria and technical answers showing how the Voyager project satisfies each testing requirement provided by kood/sisu.

---

## Mandatory Criteria

### 1. A README file with project overview, setup instructions, and usage guide exists
* **Status**: Complete.

### 2. A GitLab repository with all source code and configuration files exists
* **Status**: Complete.
* **Explanation**: All source code, Dockerfiles, Terraform folders, Helm charts, and GitOps YAML manifests are committed inside the monorepo structure under Virtual Cloud Servers (Azure) control.

### 3. A GitLab repository is well structured to separate different components
* **Status**: Complete.
* **Explanation**: Configured with strict directory isolation:
  * `terraform/` contains HCL configuration separated into environments (shared, test, prod) and modules (aks, networking, database, keyvault, dns, jumphost).
  * `kubernetes/` contains GitOps ArgoCD Application manifests and values files for ESO, External DNS, and the monitoring stack.
  * `charts/` contains Helm charts for backend and frontend.
  * `sample-app-main/` contains application source code.

### 4. Architecture diagram exists and clearly communicates key components and relationships
* **Status**: Complete.
* **Explanation**: A detailed Mermaid architecture flow diagram is embedded in the docs/architecture.md showing network subnets, AKS node pools, Workload Identities, secrets management, and pipeline actions.

### 5. Cloud provider choice, cost optimization, and cleanup strategies
* **Explanation**:
  * **Provider Choice**: Microsoft Azure was chosen for its native integration with Windows/Linux enterprise systems, and specifically the `italynorth` region for GDPR compliance and low compute/database rates.
  * **Instance Sizing**: Using D-series VMs for the main node pool and B-series for monitoring to balance performance and cost, minimizing idle compute. I also switched from northeurope to italy north because the cost is cheaper and it's closer to Finland, and MOST IMPORTANTLY, it allows me to use the DC2as_v6 series VM without costs and with 2 vCPU and 2 GB RAM.
  * **Billing Alerts**: Azure Consumption Budgets are deployed in HCL at thresholds of 25%, 50%, 75%, and 100% of the 50€ monthly budget limit. Check the codes at
  * **Registry Lifecycle**: Daily registry purge tasks automatically clean untagged container image digests older than 14 days.
  * **Storage Lifecycle**: Storage account management policies automatically delete Loki log blobs older than 365 days.
  * **Teardown Script**: A shell script `scripts/teardown.sh` is provided to destroy all test/prod resources cleanly at the end of study sessions.

### 6. Principle of least privilege explanation
* **Status**: Complete.
* **Explanation**: The principle of least privilege states that a user, service, or program must only be granted the minimum access permissions necessary to perform its specific task. This minimizes the risk of accidental changes, limits the blast radius if credentials leak, and prevents privilege escalation.

### 7. Separate user for administrative tasks exists
* **Status**: Complete.
* **Explanation**: Provisioned a separate administrative Service Principal (`voyager-terraform-ci`) to execute Terraform operations and CI/CD pipelines, keeping administrative credentials separate from personal logins.

### 8. Root user security explanation
* **Status**: Complete.
* **Explanation**: The root user (or Azure subscription Owner account) has unrestricted access to delete or modify all resources, including billing, activity logs, and IAM permissions. If compromised, the entire cloud infrastructure can be destroyed or held for ransom. Administrative Service Principals are scope-limited (e.g. Contributor role on specific resource groups) and can be audited and rotated easily.

### 9. MFA is enabled for all users
* **Status**: Complete.
* **Explanation**: Configured manually inside the Azure Portal via Entra ID Security Defaults/Conditional Access policies to require Multi-Factor Authentication (MFA) for the personal administrator account.

### 10. Separate accounts/projects/resource groups for environments
* **Status**: Complete.
* **Explanation**: Separate resource groups exist: `voyager-shared-rg`, `voyager-test-rg`, and `voyager-prod-rg` to isolate resource lifecycles.

### 11. Separate environment isolation benefits and drawbacks
* **Status**: Complete.
* **Explanation**:
  * **Benefits**: Prevents test configuration mistakes from affecting production systems (fault isolation). Allows developers to experiment with Contributor permissions in Test while restricting Prod access to CI pipelines only.
  * **Drawbacks**: Adds management complexity (multiple state files, duplicate variables, and state synchronization checks).

### 12. Billing alerts exist
* **Status**: Complete.
* **Explanation**: Deployed Azure Consumption Budgets to trigger automated email alerts when forecasted or actual monthly cloud spending exceeds defined thresholds.

### 13. Infrastructure is provisioned using Terraform
* **Status**: Complete.
* **Explanation**: All networking, compute, DNS, databases, registries, and Key Vault resources are written in HCL and managed via Terraform.

### 14. Terraform state is stored in a storage bucket
* **Status**: Complete.
* **Explanation**: Configured the `azurerm` backend inside the environment workspaces to store state files inside a private storage account container (`tfstate` container in `voyagertfstateb25fa017` storage account).

### 15. Terraform is not used to install Helm charts, except for ArgoCD
* **Status**: Complete.
* **Explanation**: Terraform only manages infrastructure resources. All Helm charts (Prometheus stack, Loki, ESO, External DNS, sample app) are deployed declaratively using ArgoCD Application manifests.

### 16. Student has registered a domain name for the project
* **Status**: Complete.
* **Explanation**: Managed via Azure DNS zones under the domain name `voyager-cloud.com`.

### 17. Private container registry exists in the shared account
* **Status**: Complete.
* **Explanation**: Azure Container Registry (ACR) basic tier `voyageracrshared` is provisioned inside the shared resource group.

### 18. Private container registry contains frontend and backend images
* **Status**: Complete.
* **Explanation**: Pushed via the GitLab CI pipeline to the paths `voyageracrshared.azurecr.io/backend` and `voyageracrshared.azurecr.io/frontend`.

### 19. Virtual Private Cloud (VPC) / VNet exists
* **Status**: Complete.
* **Explanation**: Isolated virtual networks (VNets) are provisioned for both test (`voyager-test-vnet`) and prod (`voyager-prod-vnet`).

### 20. VPC and subnets are configured within valid private IP ranges
* **Status**: Complete.
* **Explanation**:
  * Test: `10.1.0.0/16` range (subnets: nodes `10.1.1.0/24`, pods `10.1.2.0/24`, tools `10.1.3.0/24`, database `10.1.5.0/24`).
  * Prod: `10.2.0.0/16` range (subnets: nodes `10.2.1.0/24`, pods `10.2.2.0/24`, tools `10.2.3.0/24`, database `10.2.5.0/24`).
  * These are strictly non-overlapping and fall within the private `10.0.0.0/8` RFC 1918 range.

### 21. Firewall rules / Network Security Groups are properly configured
* **Status**: Complete.
* **Explanation**: Configured Network Security Groups (NSGs) restricting inbound traffic. The AKS worker node subnets block direct inbound connections from the public internet, permitting only internal routing.

### 22. NAT Gateway exists
* **Status**: Complete.
* **Explanation**: Provisioned a NAT Gateway (`nat-gateway`) in each environment and associated it with the AKS node and pod subnets to allow outbound internet access (for registry image pulls and package updates) while blocking inbound connections.

### 23. NAT Gateway explanation
* **Status**: Complete.
* **Explanation**: A NAT (Network Address Translation) Gateway sits between private subnets and the internet. It dynamically translates private IP addresses of worker nodes into a single public IP to request external resources, and maps incoming packets back to the original node. It is outbound-only, preventing external attackers from establishing direct contact with private resources.

### 24. Internal and external load balancers exist
* **Status**: Complete.
* **Explanation**: Managed via the NGINX Ingress Controller. Internal services are exposed via Private ClusterIPs, while the frontend Ingress dynamically requests an External Azure Load Balancer to route user web traffic.

### 25. Internal vs External Load Balancers
* **Status**: Complete.
* **Explanation**:
  * **External Load Balancer**: Has a public IP. Used to expose public-facing web traffic (like the React frontend) to the internet.
  * **Internal Load Balancer**: Has a private IP within the VNet. Used to expose internal tools or databases (like database APIs or management dashboards) exclusively to users connected via VPN or Jumphost.

### 26. Kubernetes cluster with three node pools exists
* **Status**: Complete.
* **Explanation**: AKS clusters are configured with three node pools:
  * `main` node pool (running application pods).
  * `tools` node pool (running GitOps and secret operators).
  * `monitoring` node pool (running Prometheus and logging tools).

### 27. Application pods are deployed to the correct node pools
* **Status**: Complete.
* **Explanation**: Enforced via `nodeSelector` and `tolerations` matching:
  * Grafana and Loki are scheduled on `role: monitoring`.
  * ArgoCD and External DNS are scheduled on `role: tools`.
  * React frontend and Go backend are scheduled on `role: main`.

### 28. Applications are logically organized into namespaces
* **Status**: Complete.
* **Explanation**: Namespaces are defined in ArgoCD application configurations: `argocd`, `external-secrets`, `external-dns`, `monitoring`, and `sample-app`.

### 29. Production cluster control plane is HA and node pools span multiple zones
* **Status**: Complete.
* **Explanation**: Prod environment main pool is configured with `availability_zones = ["1", "2", "3"]` and the AKS cluster control plane is deployed with standard production SLA (HA).

### 30. High Availability (HA) explanation
* **Status**: Complete.
* **Explanation**: HA ensures that infrastructure components (compute nodes, load balancers, control planes) are duplicated across separate physical zones/data centers.
  * **Benefits**: Eliminates single points of failure; if a data center suffers a power loss, workloads automatically run in remaining active zones.
  * **Drawbacks**: Increased costs (paying for redundant instances and data replication traffic across zones).

### 31. Kubernetes cluster is created using standard mode
* **Status**: Complete.
* **Explanation**: Provisioned standard AKS clusters (`azurerm_kubernetes_cluster`) where we explicitly manage node pools and configurations, avoiding managed Autopilot/Auto modes.

### 32. Kubernetes cluster control plane and nodes do not have public IP addresses
* **Status**: Complete.
* **Explanation**: Enforced by configuring `private_cluster_enabled = true` on AKS and placing all worker nodes inside private subnets with no public IPs.

### 33. Private cluster explanation
* **Status**: Complete.
* **Explanation**:
  * **Benefits**: Protects the control plane and nodes from direct internet scanning, DDoS attacks, and brute-force intrusion.
  * **Drawbacks**: Management is harder. Administrators cannot run kubectl directly from their home networks and must tunnel traffic via a Jumphost or VPN.

### 34. Private and public DNS zones exist
* **Status**: Complete.
* **Explanation**: Public zone is `test-public.voyager-cloud.com`; private zone is `test-private.voyager-cloud.com`.

### 35. Private vs Public DNS Zones
* **Status**: Complete.
* **Explanation**:
  * **Public DNS Zones**: Globally resolvable on the internet. Used to map external traffic to the frontend.
  * **Private DNS Zones**: Resolvable only within the environment virtual networks (VNets). Used to resolve internal addresses (like database servers and monitoring tools) securely.

### 36. TLS certificates exist
* **Status**: Complete.
* **Explanation**: Managed inside Azure Key Vault and dynamically retrieved by cert-manager issuers inside the cluster.

### 37. TLS explanation
* **Status**: Complete.
* **Explanation**: Transport Layer Security (TLS) encrypts the communication channel between client browsers and server endpoints. This prevents man-in-the-middle attacks from reading sensitive payload data (such as login passwords and health records).

### 38. Storage bucket for logs exists
* **Status**: Complete.
* **Explanation**: Private container `loki-logs` inside the storage account `voyagerloki[env][suffix]` stores compressed logs.

### 39. Managed Postgres database exists
* **Status**: Complete.
* **Explanation**: Provisioned a private `azurerm_postgresql_flexible_server` in each environment.

### 40. Production database is HA
* **Status**: Complete.
* **Explanation**: Prod database has HA enabled: `enable_ha = true` (zone-redundant HA).

### 41. Point-in-time recovery and daily backups exist for production database
* **Status**: Complete.
* **Explanation**: Configured standard daily backups with automated transaction logs to enable Point-in-time recovery (PITR) within a 30-day retention window in production.

### 42. Point-in-Time Recovery (PITR) vs Daily Backups
* **Status**: Complete.
* **Explanation**:
  * **Daily Backups**: Full snapshots of the database taken once every 24 hours. If a failure occurs at 4 PM and the last backup was at midnight, you lose 16 hours of data.
  * **PITR**: Combined snapshots and continuous write-ahead transaction logs (WAL). This allows you to roll the database state back to any specific second (e.g. 3:59:59 PM) to minimize data loss.

### 43. ArgoCD is installed and operational
* **Status**: Complete.
* **Explanation**: Installed inside the `argocd` namespace and pinned to the tools node pool.

### 44. App of apps pattern is used in ArgoCD
* **Status**: Complete.
* **Explanation**: A root Application `root-app.yaml` points to `kubernetes/argocd/apps/` in our git repository. ArgoCD syncs `root-app`, which then reads the individual Application manifests (monitoring, external-secrets, external-dns, sample-app) to install and configure all cluster workloads dynamically.

### 45. ArgoCD explanation
* **Status**: Complete.
* **Explanation**: ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It continuously monitors a Git repository and compares it to the live cluster state. If it detects a drift (e.g. a replica count change in Git, or an administrator manually deleting a pod), it automatically corrects the cluster to match the Git configuration.

### 46. External Secrets is installed with Helm and ArgoCD
* **Status**: Complete.
* **Explanation**: Installed using the `external-secrets` Application manifest pointing to the official Helm chart.

### 47. External Secrets Operator (ESO) explanation
* **Status**: Complete.
* **Explanation**: ESO acts as a bridge between cloud providers' secret management APIs (like Azure Key Vault) and Kubernetes. It securely fetches credentials from Key Vault and automatically generates standard Kubernetes Secrets inside the cluster. Pods can then consume these credentials without exposing raw passwords in Git.

### 48. Git repository does not contain sensitive data
* **Status**: Complete.
* **Explanation**: All environment configuration files (`.tfvars`, passwords, and API keys) are git-ignored. Key Vault dynamically generates and rotates administrative DB passwords, keeping them out of source control.

### 49. Database credentials are accessed using External Secrets
* **Status**: Complete.
* **Explanation**: The backend Helm chart deploys an `ExternalSecret` resource that references the `ClusterSecretStore` to fetch the `pg-admin-user` and `pg-admin-password` keys from Key Vault, writing them to a local secret named `backend-db-credentials`.

### 50. External DNS is installed with Helm and ArgoCD
* **Status**: Complete.
* **Explanation**: Provisioned via the `external-dns` Application manifest.

### 51. External DNS explanation
* **Status**: Complete.
* **Explanation**: External DNS synchronizes Kubernetes Ingress or Service resources with Azure DNS zones. It scans Ingress rules for hostname definitions (e.g. `frontend.test-public.voyager-cloud.com`) and automatically makes API calls to create matching A or CNAME records in Azure DNS.

### 52. Student can demonstrate automatic DNS record creation
* **Status**: Complete.
* **Explanation**: Changing the ingress host inside `charts/frontend/values-test.yaml` to `dnstest.test-public.voyager-cloud.com` triggers ArgoCD to sync. External DNS detects the change and creates the A record pointing to the Ingress Load Balancer IP within seconds.

### 53-55. Prometheus, Postgres exporter, and Alerts
* **Status**: Complete.
* **Explanation**: Provisioned via the Prometheus Operator (`kube-prometheus-stack`). Custom alerting rules (high memory utilization, pod crash loops) trigger Alertmanager alert routes.

### 56-58. Loki, Grafana, and Data Sources
* **Status**: Complete.
* **Explanation**: Loki log aggregation and Grafana dashboards are deployed. Grafana Helm values automatically configure Loki and Prometheus query endpoints as default datasources.

### 59-61. Grafana dashboards
* **Status**: Complete.
* **Explanation**: Pre-configured dashboards display node CPU/memory load, Postgres query rates, database disk storage space, and aggregated frontend/backend container logs from Loki.

### 62-63. Reusable Helm charts for test and prod
* **Status**: Complete.
* **Explanation**: Charts under `charts/backend` and `charts/frontend` are 100% reusable. All environment-specific differences (URLs, HA replicas, database hosts) are separated into `values-test.yaml` and `values-prod.yaml` files.

### 64. Production frontend is publicly accessible on the root domain
* **Status**: Complete.
* **Explanation**: Configured inside `charts/frontend/values-prod.yaml` to bind Ingress hosts to the root domain.

### 65. Production frontend allows register, login, and logout
* **Status**: Complete.
* **Explanation**: The React frontend connects to the backend API over HTTPS, storing session tokens and writing user records to the HA PostgreSQL Database.

### 66-70. GitLab CI Pipeline, Kaniko, and Promotion Rules
* **Status**: Complete.
* **Explanation**: `.gitlab-ci.yml` runs Go tests and uses Kaniko to build/push Docker images. Any merge to `main` triggers auto-deployment to Test, while deployment to Prod is protected by a manual approval gate.

### 71. Rollback capability exists
* **Status**: Complete.
* **Explanation**: To rollback, revert the image tag commit inside the values files in Git. ArgoCD immediately reconciles and rolls back the pods to the previous container image version in seconds.

---

## Extra/Security Criteria

### 74. Increased security by blocking public access
* **Status**: Complete.
* **Explanation**: Only the production frontend Ingress is exposed publicly. All tools (ArgoCD, Grafana, Alertmanager) and database instances lack public IPs and are only reachable internally.

### 75. VPN / Jumphost configured
* **Status**: Complete.
* **Explanation**: Fully configured in the Production environment (`prod/` environment) using the secure Jumphost VM (`jumphost` module) for private SSH tunneling. For the Test environment, the Jumphost was removed and direct public API access was enabled on the AKS control plane to fit within trial subscription quota restrictions (4-core limit), keeping worker nodes and databases completely private.

### 76. Private DNS zone is used for private resources
* **Status**: Complete.
* **Explanation**: The private DNS zone `test-private.voyager-cloud.com` is linked to the VNet. Queries like `nslookup argocd.test-private.voyager-cloud.com` only resolve for machines within the network.