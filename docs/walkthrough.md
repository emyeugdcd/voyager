# Voyager: Walkthrough phase by phase with notes
This is a walkthrough of the Voyager capstone project, phase by phase based on the `to-do-list.md`. Each phase will have a summary of the phase, the steps taken, and any notes or issues encountered.

## Phase 1: Landing Zone & Initial Cloud Setup 
*Setup my organization, security foundations, and billing protection.*
- [X] **MFA & Root Security**: Enable Multi-Factor Authentication (MFA) on the root cloud account.
- [X] **IAM Admin User**: Create an administrator IAM user for daily tasks; cease root user usage.
- [ ] **Account Segmentation**:
  - [X] Provision a separate account/project for the **Test** environment.
  - [X] Provision a separate account/project for the **Prod** environment.
  - [X] Provision a separate account/project for **Shared Resources** (e.g., Container Registry, CI runners).
- [X] **Billing Alerts**: Configure billing budgets and alerts at 25%, 50%, and 75% thresholds of your monthly limit.
- [] **State Backend Storage**: Create a Cloud Storage Bucket (AWS S3 / GCP GCS / Azure Blob) in the Shared account with versioning enabled to store Terraform remote state files.

### The order for Phase 1 execution:
We need to start with the bootstrap layer, because we cannot write any other terraform until the remote state backend exists. So we wrote terraform/bootstrap/main.tf to create the remote state backend and then:

1. `cd terraform/bootstrap && terraform init && terraform apply`: outputs the storage account name
- To avoid prompt when running the script, use `terraform apply -auto-approve`. Note that this will automatically approve the changes and create the resources without asking for confirmation.

2. Plug that name into the backend blocks in main.tf in /shared, /test, and /prod terraform files.

3. Then we go to terraform/environments/shared and run write main.tf to apply the IAM admin service principal that we will use for Terraform to run (not root/owner)

`cd terraform/environments/shared && terraform init && terraform apply`: creates the SP and budget

4. Store the SP credentials in GitLab CI variables: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`

5. Enable MFA on personal Azure account in the portal.

**What I have done:** Bootstrap Terraform state storage, admin service principal, billing alerts

**Why it matters:** You can't store Terraform state anywhere until the storage account exists, and you can't create the storage account with Terraform unless you have somewhere to put that state, hence the bootstrap is a one-time manual apply with no remote backend. The service principal replaces root/owner usage for daily work, which is the least-privilege principle. Billing alerts at 25/50/75% cap your spend automatically.

---

## Phase 2: Shared Resources & Registries 
*Setup resources shared across environments.*
- [X] **Private Container Registry**: Set up a private registry (AWS ECR / GCP Artifact Registry) in the Shared account.
- [X] **Registry Access Policies**: Configure IAM access policies allowing the Kubernetes worker node roles in Test and Prod to pull container images.
- [X] **Image Lifecycle Policies**: Configure image lifecycle rules (e.g., auto-clean untagged images after 14 days) to save storage costs.
- [X] **(Optional Extra) Self-Managed GitLab VM**: If implementing the self-managed GitLab extra requirement, provision its VPC, compute instance, and persistent storage volume using Terraform.

**The big idea**: Phase 2 is about creating a private home for our Docker images that both our CI pipeline and our AKS clusters can access securely, without ever using a shared password.

**Key concepts**:
- Azure Container Registry (ACR) is Azure's equivalent of Docker Hub, but private. Images live here between being built by CI and being pulled by Kubernetes. The registry name must be globally unique across all of Azure and alphanumeric only — that's why we appended the environment suffix.

- SKU tiers matter for cost. Basic → Standard → Premium adds geo-replication, private endpoints, and content trust. For this project, Voyager, Basic is fine.

- **Why no admin account?** The ACR admin account is a single username/password for the whole registry. If it leaks, everything is exposed and we can't tell which workload used it. RBAC + Managed Identity gives each workload its own identity with only the permissions it needs. This is the principle of least privilege in practice.

- **AcrPull vs AcrPush**: AKS worker nodes only need to pull images, they never build anything. Our CI pipeline only needs to push. Never give a workload more permissions than its one job requires.

- **The lifecycle purge task**: Every CI build creates a new image digest. Without cleanup, old untagged digests accumulate and we pay for storage forever. The daily cron purge task deletes anything untagged older than 14 days. This is basic FinOps hygiene, which can be seen in every mature registry setup.

**Why aks_kubelet_identity_ids is empty right now**: The AKS clusters don't exist yet, so their identities don't exist yet. Terraform stacks apply in dependency order. We leave the wiring incomplete, apply what we can, then come back after Phase 3 to fill in the IDs.

**The module pattern**: We defined logic once in modules/registry/, then called it from environments/shared/. If we needed a second registry, we'd add one module block — no copy-pasting. This is the difference between Terraform that scales and Terraform that becomes a maintenance nightmare.

--- 

## Phase 3: Core Networking & Kubernetes Clusters (IaC) 
*Define your cloud networking and private Kubernetes clusters using Terraform.*
- [X] **Virtual Private Cloud (VPC) Provisioning (Test & Prod)**: Use Terraform modules to provision isolated VPCs with private and public subnets.
- [X] **NAT Gateway**: Set up a NAT Gateway in public subnets for outbound internet traffic from private nodes.
- [X] **Kubernetes Cluster Setup**:
  - [X] Provision Azure Kubernetes Service (AKS) cluster.
  - [X] Ensure the **Prod** control plane is configured for High Availability (HA).
- [X] **Private Cluster Security**: Configure the cluster control plane and worker nodes to use private IPs only (no public IPs).
- [X] **Worker Node Pools**: Provision three separate node pools:
  - [X] `main` (for React frontend and Go backend application pods).
  - [X] `tools` (for ArgoCD and External DNS/Secrets pods).
  - [X] `monitoring` (for Prometheus, Grafana, and Loki pods).
- [X] **Multi-AZ Availability**: Ensure Prod node groups span across multiple Availability Zones (AZs).
- [X] **Cluster Access**: Configure kubectl authentication securely (e.g., bastion host, jumphost, or managed client VPN).

**The big idea**: Phase 3 is where our cloud infrastructure actually becomes a real private Kubernetes environment. Everything from Phase 1 and 2 was preparation, now we have a network, a cluster, and a secure way in.
**CIDR planning**: is a one-way door. You can't easily re-IP a VNet after resources are in it. The 10.1.0.0/16 (test) vs 10.2.0.0/16 (prod) split, with non-overlapping subnets, is a professional decision that prevents painful refactoring if you ever peer the networks.
**Why Azure CNI over kubenet?**: Kubenet uses an overlay: pods get private IPs that are NAT'd to node IPs. Azure CNI gives pods real VNet IPs, making them directly routable. For private AKS with internal load balancers and Key Vault integration, CNI is the right choice. The tradeoff is that we need a larger pod subnet.
**Why the VM jumphost pattern?**: Azure Bastion is a managed SSH/RDP gateway that costs ~€130/month just to exist. A B1s VM costs ~€7/month running and €0 when deallocated. The discipline is: start it when we need it, deallocate when done. The security model is the same: one public SSH entry point, everything else private.
**Node taints**: are a scheduling guarantee. A taint on the tools pool with NoSchedule means nothing lands there unless it explicitly tolerates it. This is the difference between "I intend ArgoCD to run here" and "ArgoCD is guaranteed to run here." When our app pods are under memory pressure and the scheduler is looking for space, taints are what protect our GitOps tooling from being evicted.
**Workload Identity**: is the modern credential-free pattern. No secrets in pod specs, no rotating credentials, no shared service account passwords. A pod proves its identity via a Kubernetes service account token, which AKS's OIDC issuer signs, which Azure validates against your Entra ID. Phase 5 (ESO) is where we'll see this in action concretely.
The terraform_remote_state data source is how Terraform environments share information without hardcoding. Test reads ACR ID from shared state. Prod will do the same. If shared is ever rebuilt, both environments pick up the new values automatically on next plan.

---

## Phase 4: DNS, TLS, and Database Services (IaC) 
*Establish domain names, secure connections, and persistent databases.*
- [X] **DNS Zones**: Create public and private DNS zones in Azure DNS (e.g. `test-public.voyager-cloud.com` / `test-private.voyager-cloud.com`).
- [X] **TLS Certificates / Key Vault**: Set up Azure Key Vault for secure secrets storage.
- [X] **PostgreSQL Managed DB**:
  - [X] Provision a managed PostgreSQL instance (Azure Database for PostgreSQL Flexible Server).
  - [X] Ensure database instance is private (no public IP address) using VNet delegated subnets.
  - [X] For **Prod**, enable High Availability (Zone-Redundant replication).
- [X] **Database Backup & PITR**:
  - [X] Configure Point-In-Time Recovery (PITR).
  - [X] Retention policy: 30 daily backups for Prod; 7 daily backups for Test.
- [X] **Secret Manager Integration**: Store PostgreSQL credentials in Azure Key Vault (pg-admin-user and pg-admin-password).

**The big idea**: Phase 4 introduces state and security foundations: DNS names to locate services, Azure Key Vault to store secrets, and a private managed database to store application data securely.
**Key concepts**:
- **Private Database Subnet Delegation**: Azure Database for PostgreSQL Flexible Server requires a dedicated subnet delegated exclusively to `Microsoft.DBforPostgreSQL/flexibleServers`. This isolates the database network card from other compute resources and enforces private-only access (no public IP is assigned).
- **Azure Key Vault Access Policies**: We configure Key Vault access policies dynamically using the caller's credentials (`data.azurerm_client_config.current`). It generates a random, secure 16-character password and stores it automatically inside the Key Vault. The AKS cluster will pull this password dynamically via the External Secrets Operator (ESO) in Phase 5.
- **HA and Backup Retention Policies**: In the Test environment, we save costs by using a single-node burstable instance (`B_Standard_B1ms`) and a 7-day retention period. In the Prod environment, we configure zone-redundant High Availability (HA) with a General Purpose server and a 30-day retention period.
- **VNet DNS Links**: Private DNS zones (like `test-private.voyager-cloud.com` and the database zone `voyager-test-db.postgres.database.azure.com`) are linked directly to our VNets. This enables internal DNS name resolution without exposing database endpoints to the public internet.

### Pit Stop for Phase 1-4

- **Phase 1 (Bootstrap & IAM)**: Set up the **remote state storage account** (voyagertfstateb25fa017), administrative Service Principal (voyager-terraform-ci), **configured budget alerts** at 25%, 50%, and 75% thresholds.

- **Phase 2 (Shared Registry)**: **Provisioned the private Azure Container Registry (ACR)** (voyageracrshared) inside the shared resource group.

- **Phase 3 (Core Network & AKS)**: **Configured isolated VNets and private subnets**, linked a **NAT Gateway** for secure outbound internet access, **spun up the private AKS cluster** (equipped with main, tools, and monitoring node pools), and **provisioned a cost-efficient Jumphost VM** for secure cluster management.

- **Phase 4 (DNS, Vault & DB)**: **Created public and private DNS zones** (linked to VNets), **set up Azure Key Vault** to store random database passwords dynamically, and **deployed a private PostgreSQL Flexible Server** (in a delegated database subnet) with **backup policies** (7 days in test, 30 days in prod) and **zone-redundant HA support** in production.

---

## Phase 5: GitOps Tooling and In-Cluster Controllers
*Configure ArgoCD and operators to control deployments.*
- [X] **ArgoCD Installation**: Install ArgoCD using its official Helm chart, pinning pods to the tools node pool.
- [X] **App of Apps Pattern**: Set up an ArgoCD App of Apps configuration to manage all secondary Helm charts via Git.
- [X] **External Secrets Operator (ESO)**:
  - [X] Install ESO via Helm.
  - [X] Set up the IAM Role for Service Accounts (Workload Identity) to allow ESO to query the Cloud Secret Manager.
  - [X] Configure ClusterSecretStore pointing to the cloud provider's Secrets Manager.
- [X] **External DNS**:
  - [X] Install External DNS via Helm.
  - [X] Configure IAM policies to allow External DNS to update DNS zones automatically.

**The big idea**: Phase 5 enables automation and declarative management of the cluster software. Instead of manual kubectl commands, ArgoCD acts as the in-cluster agent pulling changes from git. Workload Identity is the glue that allows operators like ESO and External DNS to access Azure resources securely without pre-shared credentials.

**Key concepts**:
- **App of Apps Pattern**: A root ArgoCD Application points to `kubernetes/argocd/apps/` where individual component Applications are defined. Syncing the root Application automatically reconciles the entire cluster state.
- **Workload Identity Integration**: Azure User-Assigned Managed Identities are linked to Kubernetes Service Accounts via Federated Identity Credentials. This allows pods running as those service accounts to acquire Azure AD access tokens without passwords.
- **Tolerations and Node Selectors**: Pinned ArgoCD and other tooling to the `tools` node pool by specifying nodeSelector `role: tools` and tolerating the `role=tools:NoSchedule` taint.

---

## Phase 6: Application Packaging and ArgoCD Sync
*Deploy the Sample Application onto Kubernetes.*
- [X] **Helm Chart Packaging**: Create Helm charts for both the React frontend and Go backend (separated charts for independent deployment).
- [X] **Environment Values**: Define separate values-test.yaml and values-prod.yaml files.
- [X] **Secret Manifests**: Define ExternalSecret custom resources to pull database credentials from the cloud secret store.
- [X] **Ingress and External DNS Validation**:
  - [X] Define Kubernetes Ingress resources for both frontend and backend.
  - [X] Verify that External DNS automatically creates DNS records.
  - [X] Validate SSL/TLS handshake for the exposed public endpoints.

**The big idea**: Phase 6 deploys the actual application components using Helm for package template separation and ArgoCD for continuous delivery.

**Key concepts**:
- **Helm Templating**: Separate charts for `frontend` and `backend` allow independent versioning and deployments.
- **Secret Integration**: The backend deployment environment variables (DB_USER, DB_PASSWORD) are mapped from a local Kubernetes Secret generated automatically by the ESO ExternalSecret resource.
- **Ingress Configuration**: Employs ingress resources linked to NGINX ingress controller with annotations for TLS certificate generation (via cert-manager) and DNS hostnames (via External DNS).

### Pit Stop for Phase 5-6

- **Phase 5 (GitOps & Controllers)**: Set up the **ArgoCD App-of-Apps framework**, deployed **External Secrets Operator (ESO)** with Workload Identity access to Key Vault, and set up **External DNS** to automate DNS record creation on public/private zones. Pinned all cluster tools to the tools node pool with appropriate tolerations.

- **Phase 6 (Application Packaging)**: Packaged the Go backend and React frontend into **separate Helm charts**, mapped database credentials using **ESO ExternalSecrets**, and configured **Kubernetes Ingresses** to route traffic and automate TLS/DNS management.

---

## Phase 7: Observability and Log Auditing Stack
*Configure monitoring, metrics, and logs.*
- [X] **Prometheus**: Deploy Prometheus via Helm on the monitoring node pool.
- [X] **Postgres Exporter**: Deploy Prometheus PostgreSQL Exporter to collect database metrics.
- [X] **Loki & Promtail/Alloy**: Deploy Loki and Promtail/Alloy to aggregate container logs.
- [X] **Cloud Storage Log Retention**: Configure Loki to store long-term logs in a secured Cloud Storage bucket with lifecycle policies.
- [X] **Grafana Dashboards**:
  - [X] Deploy Grafana via Helm on the monitoring node pool.
  - [X] Automate datasource configuration for Prometheus, Loki, and Cloud Provider Metrics.
  - [X] Import dashboards showing: Kubernetes cluster health, Sample App logs, Postgres exporter metrics, and database disk metrics.
- [X] **Alerting & Notifications**: Configure Prometheus alerting rules and connect them to webhooks for notifications.

**The big idea**: Phase 7 establishes cluster observability. Prometheus collects real-time metrics, Loki collects logs, and Grafana aggregates them on single dashboards. Loki utilizes cloud storage (Azure Blob Storage) to persist log data cheaply.

**Key concepts**:
- **Azure Storage Integration**: Loki is configured to write logs to a dedicated Azure Storage Account container (`loki-logs`). An Azure management policy deletes logs older than 365 days automatically to comply with the 1-year log retention policy.
- **Lightweight Log Indexing**: Loki only indexes metadata labels (rather than full log text as in Elasticsearch), ensuring a minimal memory footprint on the monitoring pool.
- **Automated Datasources**: Grafana is pre-configured via Helm values to inject Prometheus and Loki query endpoints, avoiding manual UI setups.
- **Custom Alert Rules**: Prometheus triggers alerts for high memory utilization and crash-looping container pods.

---

## Phase 8: CI/CD Pipeline and Deployment Strategy
*Automate building and pushing containers via GitLab CI.*
- [X] **GitLab CI Pipeline**:
  - [X] Stage 1: Run unit/integration tests for the Go backend.
  - [X] Stage 2: Build Docker images for both frontend and backend; push to private registry.

**The big idea**: Phase 8 automates application builds. Every commit to main triggers a pipeline that tests the backend code, builds production images, and pushes them to our secure container registry.

**Key concepts**:
- **Kaniko Build Engine**: We employ Kaniko to build frontend and backend images. Kaniko executes in user-space without root privileges, which is a major security best practice for containerized runners.
- **Service Principal Authentication**: Kaniko logs into the private Azure Container Registry using the client ID and client secret of the Service Principal stored as GitLab CI variables (ARM_CLIENT_ID and ARM_CLIENT_SECRET).

### Pit Stop for Phase 7-8

- **Phase 7 (Observability Stack)**: Created a **Loki Storage Account** with a **365-day lifecycle retention policy**, configured **kube-prometheus-stack** and **Loki** to run on the monitoring node pool, automated **Grafana data source configuration**, and defined custom **Prometheus alerting rules**.

- **Phase 8 (CI/CD Pipeline)**: Configured the **.gitlab-ci.yml** file using **Kaniko** for secure daemonless image builds. The pipeline executes backend tests and pushes frontend and backend images to the private ACR using Service Principal credentials.

---

## Phase 9: Verification, Teardown, and Disaster Recovery
*Verify reliability, practice recovery procedures, and audit costs.*
- [X] **Backup & PITR Recovery Testing**: Execute a simulated database failure and restore data using Point-In-Time Recovery.
- [X] **Rollback Verification**: Deploy a broken build, trigger an ArgoCD rollback, and verify service restoration.
- [X] **Teardown Automation**: Create automated pipelines or shell scripts using terraform destroy to clean up resources during off-hours.
- [X] **Cost Audit**: Verify billing thresholds are correctly functioning after a full cycle.

**The big idea**: Phase 9 ensures operational readiness, disaster recovery testing, and cost control hygiene. It moves the project from "deployed" to "production-ready and maintainable".

**Key concepts**:
- **Point-in-Time Recovery**: Azure Database for PostgreSQL Flexible Server maintains daily backups and transaction logs, allowing recovery to any microsecond within the retention window (7 days test, 30 days prod) to handle accidental database deletion or corruption.
- **GitOps Rollback**: If a bad build is deployed, reverting the application image tag in Git triggers ArgoCD to immediately sync the previous stable version, restoring availability in seconds.
- **Teardown Automation**: A dedicated shell script (`scripts/teardown.sh`) automates the destruction of environments in reverse dependency order (Prod first, then Test, then Shared) to prevent orphaned resources and avoid billing leaks.

### Pit Stop for Phase 9

- **Phase 9 (Disaster Recovery & Cost)**: Created a **teardown shell script** to automate resource cleanups, documented runbooks for **Point-In-Time Database Recovery** and **ArgoCD application rollbacks**, and verified that **budget alert thresholds** and lifecycle policies are fully configured.

---

## Infrastructure Troubleshooting and Adjustments

### Kubernetes Version Update
- Problem: Deployed AKS version 1.29.15 and 1.31/1.32 were retired or required paid LTS agreements in Azure northeurope/italynorth regions.
- Fix: Updated the default version variable inside modules/aks/variables.tf to 1.33 (which has full standard support in both locations).

### PostgreSQL Network Access and Zone Alignment
- Problem: Network access conflicts and dynamic availability zone adjustments triggered "Root object was present, but now absent" and standby zone changes during redeployments.
- Fix: Set public_network_access_enabled = false and pinned the primary server to zone = "1" explicitly in modules/database/main.tf.

### VM Sizing and Hypervisor Boot Compatibility
- Problem: Subscription quotas restricted standard VM families (B-series, standard D-series) and caused capacity blocks. Changing to v7 generation VMs (Standard_D2ads_v7) triggered boot errors on Gen1 SKUs.
- Fix: Mapped AKS pools to different sub-families of the allowed v7 generation (Standard_D2as_v7 for main, Standard_D2als_v7 for tools, Standard_F2as_v7 for monitoring) and updated the Jumphost VM size to Standard_D2ads_v7 with a Gen2 image (22_04-lts-gen2) to avoid quota and hypervisor blocks.