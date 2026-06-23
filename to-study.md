# 📚 Voyager: Study Guide & Free Resources

This study guide is designed to help you master the key architectural concepts needed to build and defend your Capstone Cloud Migration project. Each section includes curated, free resources you can study in 15–20 minutes.

---

## 🗺️ 1. Multi-Account Landings & IAM Roles (Principle of Least Privilege)

### Core Concepts to Study:
* **AWS Organizations & GCP Projects**: How separating accounts isolates environments (Test, Prod, Shared) so a failure or compromise in Test never impacts Prod.
* **OIDC / IAM Roles for Service Accounts (IRSA)**: How Kubernetes pods assume cloud IAM roles securely without storing hardcoded IAM keys inside the cluster.

### Free Resources:
* 📖 **AWS Documentation**: [AWS Multiple Account Billing Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/multiple-account-billing-strategy.html)
* 📖 **Google Cloud**: [Resource Hierarchy & Organization Structures](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy)
* 🎥 **YouTube**: [AWS IAM Tutorial - Identity & Access Management](https://www.youtube.com/watch?v=k1oR12tT9K0) by TechWorld with Nana

---

## 🏗️ 2. Production-Grade Terraform (IaC)

### Core Concepts to Study:
* **Remote State Backend**: Why storing state files (`.tfstate`) in S3/GCS with DynamoDB/GCS locking is required to prevent concurrent changes and state corruption.
* **Terraform Modules**: Packaging infrastructure elements (VPC, GKE, RDS) into reusable components.

### Free Resources:
* 💻 **Interactive Course**: [HashiCorp Developer Tutorials: Get Started - Terraform](https://developer.hashicorp.com/terraform/tutorials) (Completely Free)
* 🎥 **YouTube Course**: [Terraform Course - Course for Beginners](https://www.youtube.com/watch?v=SLB_c_ayRMc) by freeCodeCamp (5 hours, high quality)
* 📖 **Guide**: [Terraform Best Practices](https://www.terraform-best-practices.com/) by Anton Babenko

---

## ☸️ 3. Private Kubernetes Architecture & Node Group Sizing

### Core Concepts to Study:
* **Private EKS/GKE Clusters**: Disabling public IPs on node pools. How nodes pull images using Nat Gateways.
* **Custom Node Pools**: Why separate node pools (`main`, `tools`, `monitoring`) are used to prevent resource-heavy monitoring agents from choking production application traffic.

### Free Resources:
* 📖 **Kubernetes Docs**: [Kubernetes Node Pools & Taints/Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
* 🎥 **YouTube**: [Kubernetes Networking Demystified](https://www.youtube.com/watch?v=8VnQ4hUvW3Y) by TechWorld with Nana
* 📖 **EKS Guide**: [AWS EKS Best Practices Guide for Security](https://aws.github.io/aws-eks-best-practices/security/docs/)

---

## 🔑 4. External Secrets Operator (ESO) & Secrets Manager

### Core Concepts to Study:
* **Secrets Decoupling**: Why base64-encoded Kubernetes secrets committed to Git are a security risk.
* **ESO Controller**: How ESO automatically polls AWS Secrets Manager / GCP Secret Manager and dynamically populates local Kubernetes Secrets.

### Free Resources:
* 📖 **Official Site**: [External Secrets Operator Documentation](https://external-secrets.io/latest/)
* 🎥 **YouTube**: [Manage Secrets in Kubernetes with External Secrets Operator](https://www.youtube.com/watch?v=Jm_5C_D1x0Y) by Anton Putiputo

---

## 🌐 5. ExternalDNS & Ingress Controller Integrations

### Core Concepts to Study:
* **Automated Record Management**: How ExternalDNS queries your Kubernetes Ingress manifests and calls cloud Route53 / Google Cloud DNS APIs to dynamically create public/private DNS records.

### Free Resources:
* 📖 **GitHub Docs**: [ExternalDNS Kubernetes Controller](https://github.com/kubernetes-sigs/external-dns)
* 🎥 **YouTube**: [Exposing Kubernetes Applications with Ingress and ExternalDNS](https://www.youtube.com/watch?v=8jWfNisjW2I) by DevOps Toolkit

---

## 🤖 6. GitOps: ArgoCD "App of Apps" Pattern

### Core Concepts to Study:
* **App of Apps Pattern**: Using a single "bootstrap" ArgoCD Application to manage, install, and update all other ArgoCD applications (Prometheus, App Frontend, App Backend, etc.).
* **Pull-based vs. Push-based CI/CD**: Why ArgoCD's pull method improves security and isolates Kubernetes API access.

### Free Resources:
* 📖 **ArgoCD Docs**: [ArgoCD App of Apps Pattern Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
* 🎥 **YouTube**: [Argo CD Tutorial - GitOps on Kubernetes](https://www.youtube.com/watch?v=MeU5_F9y2xM) by TechWorld with Nana
* 💻 **Course**: [Introduction to GitOps (LFS169)](https://training.linuxfoundation.org/training/introduction-to-gitops/) - Linux Foundation (Free enrollment)

---

## 📊 7. Advanced Observability (Prometheus, Loki, Alloy, Grafana)

### Core Concepts to Study:
* **Log Ingestion & Compression**: How Loki ingests compressed chunks and queries metadata instead of full indexing (like Elasticsearch).
* **Grafana Provisioning**: Automating data source and dashboard setup using Helm values (`configMaps`) rather than manual UI clicks.

### Free Resources:
* 📖 **Grafana Labs**: [Grafana In-Depth Tutorials & Learning Paths](https://grafana.com/tutorials/)
* 🎥 **YouTube**: [Loki & Promtail Tutorial - Log Aggregation](https://www.youtube.com/watch?v=I7X9gR4d5uU) by Marcel Dempers
* 📖 **Prometheus Docs**: [Getting Started with Prometheus Metrics Collection](https://prometheus.io/docs/introduction/overview/)
