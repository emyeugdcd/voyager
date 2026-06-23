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