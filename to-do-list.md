# 🚀 Voyager: Cloud Migration Capstone Checklist

This checklist tracks your progress through the migration of the Sample Application (React frontend, Go backend, PostgreSQL) and its accompanying observability/CI/CD stack to a cloud provider (AWS/GCP/Azure) using Terraform, ArgoCD, and GitLab CI.

---

## Phase 1: Landing Zone & Initial Cloud Setup 🏢
*Setup your organization, security foundations, and billing protection.*
- [x] **MFA & Root Security**: Enable Multi-Factor Authentication (MFA) on the root cloud account.
- [x] **IAM Admin User**: Create an administrator IAM user for daily tasks; cease root user usage.
- [x] **Account Segmentation**:
  - [x] Provision a separate account/project for the **Test** environment.
  - [x] Provision a separate account/project for the **Prod** environment.
  - [x] Provision a separate account/project for **Shared Resources** (e.g., Container Registry, CI runners).
- [x] **Billing Alerts**: Configure billing budgets and alerts at 25%, 50%, and 75% thresholds of your monthly limit.
- [x] **State Backend Storage**: Create a Cloud Storage Bucket (AWS S3 / GCP GCS / Azure Blob) in the Shared account with versioning enabled to store Terraform remote state files.

---

## Phase 2: Shared Resources & Registries 📦
*Setup resources shared across environments.*
- [ ] **Private Container Registry**: Set up a private registry (AWS ECR / GCP Artifact Registry) in the Shared account.
- [ ] **Registry Access Policies**: Configure IAM access policies allowing the Kubernetes worker node roles in Test and Prod to pull container images.
- [ ] **Image Lifecycle Policies**: Configure image lifecycle rules (e.g., auto-clean untagged images after 14 days) to save storage costs.
- [ ] **(Optional Extra) Self-Managed GitLab VM**: If implementing the self-managed GitLab extra requirement, provision its VPC, compute instance, and persistent storage volume using Terraform.

---

## Phase 3: Core Networking & Kubernetes Clusters (IaC) 🌐
*Define your cloud networking and private Kubernetes clusters using Terraform.*
- [ ] **VPC Provisioning (Test & Prod)**: Use Terraform modules to provision isolated VPCs with private and public subnets.
- [ ] **NAT Gateway**: Set up a NAT Gateway in public subnets for outbound internet traffic from private nodes.
- [ ] **Kubernetes Cluster Setup**:
  - [ ] Provision GKE Standard / AWS EKS cluster (no GKE Autopilot or EKS Auto Mode).
  - [ ] Ensure the **Prod** control plane is configured for High Availability (HA).
- [ ] **Private Cluster Security**: Configure the cluster control plane and worker nodes to use private IPs only (no public IPs).
- [ ] **Worker Node Pools**: Provision three separate node pools:
  - [ ] `main` (for React frontend and Go backend application pods).
  - [ ] `tools` (for ArgoCD and External DNS/Secrets pods).
  - [ ] `monitoring` (for Prometheus, Grafana, and Loki pods).
- [ ] **Multi-AZ Availability**: Ensure Prod node groups span across multiple Availability Zones (AZs).
- [ ] **Cluster Access**: Configure kubectl authentication securely (e.g., bastion host, jumphost, or managed client VPN).

---

## Phase 4: DNS, TLS, and Database Services (IaC) 🔏
*Establish domain names, secure connections, and persistent databases.*
- [ ] **DNS Zones**: Create public and private DNS zones in AWS Route53 or Google Cloud DNS for each environment (e.g., `test-public.domain.com` / `test-private.domain.com`).
- [ ] **TLS Certificates**: Configure TLS certificates (AWS Certificate Manager or GCP Certificate Manager) for both public and private subnets (wildcard certificates recommended).
- [ ] **PostgreSQL Managed DB**:
  - [ ] Provision a managed PostgreSQL instance (AWS RDS / GCP Cloud SQL).
  - [ ] Ensure database instance is private (no public IP address).
  - [ ] For **Prod**, enable High Availability (Multi-AZ replication).
- [ ] **Database Backup & PITR**:
  - [ ] Configure Point-In-Time Recovery (PITR).
  - [ ] Retention policy: 30 daily backups for Prod; 7 daily backups for Test.
- [ ] **Secret Manager Integration**: Store PostgreSQL credentials in the cloud secrets store (AWS Secrets Manager / GCP Secret Manager).

---

## Phase 5: GitOps Tooling & In-Cluster Controllers 🤖
*Configure ArgoCD and operators to control deployments.*
- [ ] **ArgoCD Installation**: Install ArgoCD using its official Helm chart, pinning pods to the `tools` node pool.
- [ ] **App of Apps Pattern**: Set up an ArgoCD "App of Apps" configuration to manage all secondary Helm charts via Git.
- [ ] **External Secrets Operator (ESO)**:
  - [ ] Install ESO via Helm.
  - [ ] Set up the IAM Role for Service Accounts (IRSA/Workload Identity) to allow ESO to query the Cloud Secret Manager.
  - [ ] Configure `ClusterSecretStore` pointing to the cloud provider's Secrets Manager.
- [ ] **External DNS**:
  - [ ] Install External DNS via Helm.
  - [ ] Configure IAM policies to allow External DNS to update Route53 / Google Cloud DNS zones automatically.

---

## Phase 6: Application Packaging & ArgoCD Sync 🚀
*Deploy the Sample Application onto Kubernetes.*
- [ ] **Helm Chart Packaging**: Create Helm charts for both the React frontend and Go backend (separated charts for independent deployment).
- [ ] **Environment Values**: Define separate `values-test.yaml` and `values-prod.yaml` files.
- [ ] **Secret Manifests**: Define `ExternalSecret` custom resources to pull database credentials from the cloud secret store.
- [ ] **Ingress & External DNS Validation**:
  - [ ] Define Kubernetes Ingress resources for both frontend and backend.
  - [ ] Verify that External DNS automatically creates DNS records (e.g., `frontend.test-public.example.com`).
  - [ ] Validate SSL/TLS handshake for the exposed public endpoints.

---

## Phase 7: Observability & Log Auditing Stack 📊
*Configure monitoring, metrics, and logs.*
- [ ] **Prometheus**: Deploy Prometheus via Helm on the `monitoring` node pool.
- [ ] **Postgres Exporter**: Deploy Prometheus PostgreSQL Exporter to collect database metrics.
- [ ] **Loki & Promtail/Alloy**: Deploy Loki and Promtail/Alloy to aggregate container logs.
- [ ] **Cloud Storage Log Retention**: Configure Loki to store long-term logs in a secured Cloud Storage bucket with lifecycle policies (1-month retention for metrics; 1-year retention for logs).
- [ ] **Grafana Dashboards**:
  - [ ] Deploy Grafana via Helm on the `monitoring` node pool.
  - [ ] Automate datasource configuration for Prometheus, Loki, and Cloud Provider Metrics (CloudWatch/Stackdriver).
  - [ ] Import dashboards showing: Kubernetes cluster health, Sample App logs, Postgres exporter metrics, and database disk metrics.
- [ ] **Alerting & Notifications**: Configure Prometheus alerting rules and connect them to webhooks for notifications (Slack/Discord/Teams).

---

## Phase 8: CI/CD Pipeline & Deployment Strategy 🏗️
*Automate building and pushing containers via GitLab CI.*
- [ ] **GitLab CI Pipeline**:
  - [ ] Stage 1: Run unit/integration tests for the Go backend.
  - [ ] Stage 2: Build Docker images for both frontend and backend; push to private registry.
  - [ ] Stage 3: Push Helm charts to the OCI registry (optional).
- [ ] **GitOps Integration**: Set up ArgoCD CLI triggers in the pipeline using an ArgoCD API token.
- [ ] **Environment Promotion Rules**:
  - [ ] Any commit to `main` triggers automatic deployment to the **Test** environment.
  - [ ] Pause the pipeline before deployment to the **Prod** environment (requires manual approval gate).
  - [ ] Ensure production deployment is only available after a successful test deployment.
- [ ] **Rollback Strategy**: Write a rollback runbook and verify automated deployment fallback in case of sync failures.

---

## Phase 9: Verification, Teardown, and Disaster Recovery 🌪️
*Verify reliability, practice recovery procedures, and audit costs.*
- [ ] **Backup & PITR Recovery Testing**: Execute a simulated database failure and restore data using Point-In-Time Recovery.
- [ ] **Rollback Verification**: Deploy a broken build, trigger an ArgoCD rollback, and verify service restoration.
- [ ] **Teardown Automation**:
  - [ ] Create automated pipelines or shell scripts using `terraform destroy` or `aws-nuke` to clean up resources during off-hours.
- [ ] **Cost Audit**: Verify billing thresholds are correctly functioning after a full cycle.
