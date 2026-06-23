# 🛠️ Voyager: Installation Guide & Toolkit

This document outlines the system packages, CLIs, and configuration tools you need to install locally on your machine to manage, debug, and automate your cloud-migrated Kubernetes cluster and Terraform workspaces.

---

## ☁️ 1. Cloud Provider CLIs

Choose the CLI corresponding to the cloud provider you decided to migrate to.

### AWS CLI (Amazon Web Services)
Allows authentication and command-line management of AWS resources (EC2, EKS, RDS, S3).
* **Install (macOS)**:
  ```bash
  brew install awscli
  ```
* **Install (Linux)**:
  ```bash
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  ```
* **Verify**: `aws --version`
* **Setup**: `aws configure`

### Google Cloud CLI (GCP)
Used for interacting with GKE, Cloud SQL, Cloud DNS, and Cloud Storage.
* **Install (macOS)**:
  ```bash
  brew install --cask google-cloud-sdk
  ```
* **Install (Linux)**: Follow the [GCP SDK apt guide](https://cloud.google.com/sdk/docs/install#deb).
* **Verify**: `gcloud --version`
* **Setup**: `gcloud init`

### Azure CLI
Allows authentication and command-line management of Azure resources (AKS, Azure SQL, Azure DNS, Azure Storage).
* **Install (macOS)**:
  ```bash
  brew install azure-cli
  ```
* **Install (Linux)**: Follow the [Azure CLI Linux installation guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux).
* **Verify**: `az --version`
* **Setup**: `az login`

---

## 🏗️ 2. Infrastructure as Code (IaC)

### Terraform
Required for provisioning all cloud components (VPC, databases, Kubernetes clusters, KMS, IAM).
* **Install (macOS)**:
  ```bash
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
  ```
* **Install (Linux)**: Follow the [HashiCorp Linux install guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
* **Verify**: `terraform -version`

### TFLint & TFSec (Security and Linting)
Linters and static security code analyzers for Terraform to catch misconfigurations before deployment.
* **Install (macOS)**:
  ```bash
  brew install tflint tfsec
  ```
* **Verify**: `tflint --version` and `tfsec --version`

---

## ☸️ 3. Kubernetes & GitOps CLIs

### kubectl
The command-line tool for controlling Kubernetes clusters.
* **Install (macOS)**:
  ```bash
  brew install kubectl
  ```
* **Verify**: `kubectl version --client`

### Helm
The package manager for Kubernetes, used to package the Sample application and install third-party charts (ArgoCD, Prometheus, Loki).
* **Install (macOS)**:
  ```bash
  brew install helm
  ```
* **Verify**: `helm version`

### ArgoCD CLI
Allows command-line interaction with your ArgoCD instance (syncing, diffing, and token generation).
* **Install (macOS)**:
  ```bash
  brew install argocd
  ```
* **Verify**: `argocd version --client`

### kubectx & kubens
Extremely helpful productivity tools for switching between Kubernetes clusters and namespaces.
* **Install (macOS)**:
  ```bash
  brew install kubectx
  ```
* **Usage**:
  * Switch namespace: `kubens sample-app`
  * Switch cluster: `kubectx test-cluster`

---

## 🔍 4. Troubleshooting, Logs & Monitoring

### k9s
A terminal UI for interacting with your Kubernetes clusters. Makes it easy to view logs, check pod status, restart deployments, and inspect secrets.
* **Install (macOS)**:
  ```bash
  brew install k9s
  ```
* **Run**: `k9s`

### Stern
Allows you to tail multiple containers on Kubernetes and stream their logs in real-time with color-coding. Very useful for debugging frontend and backend container interactions.
* **Install (macOS)**:
  ```bash
  brew install stern
  ```
* **Usage**: `stern backend -n sample-app`

---

## 🐳 5. Containers & CI/CD

### Docker / Colima
Required to build your application containers and push them to your private registry.
* **Install (macOS - Desktop)**: Download Docker Desktop.
* **Install (macOS - Open Source CLI alternative)**:
  ```bash
  brew install colima docker
  colima start
  ```
* **Verify**: `docker info`
