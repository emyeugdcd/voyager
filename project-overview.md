Voyager
The situation 👀
You've crunched the numbers, analyzed the costs, and mapped the digital landscape. Now it's time to transform those calculations into creation.
In this final project, you'll take your cost-analysis insight and build something real that scales, serves, and survives in the cloud.
This project simulates a common real-world technical home assignment, enhanced with additional components to provide a deeper, more comprehensive understanding of cloud infrastructure.
You'll design, implement, and maintain a complete cloud environment while making informed technical decisions throughout the process.
Upon completion, you'll gain both practical experience and conceptual knowledge of the cloud migration process, preparing you for similar challenges in professional settings.
Functional requirements 📋
In this project, you'll perform a cloud migration for a Sample application, which consists of a React frontend, Go backend, and PostgreSQL database.
The setup will also include a monitoring stack with Grafana, Prometheus, Prometheus Postgres exporter, Loki and Promtail/Alloy.
CI/CD will be handled by GitLab CI, Helm charts and ArgoCD.
The application must be deployed to at least two environments: test and prod.
Separate account must be used for shared resources.
The goal is to use your knowledge from the previous project to perform a successful migration to the cloud provider of your choice: AWS, Google Cloud or Azure
This project might seem overwhelming at first, but don't worry! Do not create everything from scratch. Try to use existing community Terraform modules and Helm charts where possible. The goal is not to become a Terraform or Helm expert, but to understand the process and be able to make informed decisions when it comes to cloud migrations. Use your best judgment to make reasonable choices and don't overcomplicate.
Git
In this project, you will use a monorepo structure, which means you will have a single repository for all of your code. In real-world scenarios, you may have multiple repositories for different parts of your codebase. There is no such thing as the ideal solution. It all depends on the usecase of your project. Both options are valid and have their own advantages and disadvantages.
GitLab
Set up GitLab account
Create a new GitLab project
Example repository structure:
├── argocd
│   ├── test
│   │   └── applications
│   │       ├── templates
│   │       │   ├── backend.yaml
│   │       │   ├── frontend.yaml
│   │       │   ├── external-dns.yaml
│   │       │   └── ...
│   │       ├── Chart.yaml
│   │       ├── values-frontend.yaml
│   │       ├── values-backend.yaml
│   │       ├── values-external-dns.yaml
│   │       ├── ...
│   │       └── values.yaml
│   └── prod
│       └── applications
│           ├── templates
│           │   ├── backend.yaml
│           │   └── ...
│           ├── ...
│           └── values.yaml
├── sample-app
│   ├── backend
│   │   ├── cmd
│   │   ├── helm
│   │   └── ...
│   └── frontend
│       ├── config
│       ├── helm
│       └── ...
├── terraform
│   ├── prod
│   ├── shared
│   ├── test
│   │   ├── main.tf
│   │   ├── vpc.tf
│   │   ├── dns.tf
│   │   ├── gke.tf
│   │   ├── helm.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── ...
│   └── ...
└── ...
Landing Zone
In an ideal scenario, everything would be created with infrastructure as code (IaC), however in some cases it might be more optimal to use the Cloud Console (GUI) or CLI. For example, to set up the initial landing zone, including the following:
Identity and Access Management (IAM)
Set up AWS/Google Cloud organization or equivalent
Set up the root user (root user must not be used for everyday tasks)
Set up the admin user
Enable MFA for all accounts
All accounts must follow the principle of least privilege.
Set up separate AWS account, Google Cloud project or equivalent for each environment (test and prod)
Set up separate AWS account, Google Cloud project or equivalent for shared resources (e.g., Container Registry)
General
Set up billing alerts (25%, 50%, 75% thresholds)
Set up storage bucket for Terraform backend (to store Terraform state)
Domain Name System (DNS)
Register domain name at the registrar of your choice. You can use the cloud provider's DNS service (e.g., AWS Route53, Google Cloud Domains) or use a third-party DNS registrar. You can use an existing domain name or register a new one. You need one root domain (e.g., example.com)
Infrastructure as Code for shared account
The shared account should be used for the resources that are shared between different environments (e.g., Container Registry or self-managed GitLab if applicable). It should be separate from the test and prod accounts. Be sure to configure required IAM permissions to allow the test and prod kubernetes nodes to access the container images or ArgoCD to pull Helm charts (if OCI registry is used). Always use the least privilege principle.
Storage
Set up private container/artifact registry using the cloud provider's service (e.g., AWS ECR, Google Artifact Registry)
Create repositories for images
Configure access policies, encryption, lifecycle policies
Infrastructure as Code with Terraform for test and prod
Do not create everything from scratch, but use Terraform modules for standard components. Create the infrastructure for test environment first, then use the same components for prod environment. The only differences between the environments should be in input variables. The goal is to have a similar architecture for both environments. There is no such thing as the ideal solution. Good enough is good enough, so keep it simple and don't overengineer it.
Network
Set up Virtual Private Cloud (VPC)
Configure subnets
Use private IPv4 address ranges
Create security groups/network ACLs/firewall rules
Configure NAT gateway
Kubernetes
Create Kubernetes cluster with three node groups/pools (monitoring, tools, main)
EKS Auto Mode, GKE Autopilot mode or equivalent is not allowed
Set correct IAM permissions for the nodes (remember to use the least privilege principle)
Use private nodes (no public IP addresses for control plane or kubernetes nodes)
Set up access the cluster with kubectl for debugging and troubleshooting purposes (e.g., via jumphost, VPN etc.)
Production cluster control plane must be Highly Available (HA)
Production cluster node groups/pools must be spread across multiple availability zones
Configure firewall rules, security groups or equivalent
Domain Name Service (DNS)
Create public and private DNS zones for each environment (e.g., test-public.example.com, test-private.example.com, prod-private.example.com, prod-public.example.com)
Configure TLS certificates with cloud provider services for both public and private DNS zones (e.g., AWS Certificate Manager, Google Cloud Certificate Manager)
If feeling creative, you can configure wildcard TLS certificates (e.g., *.test-private.example.com)
Cloud Storage
Set up storage bucket for logs (e.g., AWS S3, Google Cloud Storage Bucket or equivalent)
Configure access policies, encryption, lifecycle policies (e.g., soft delete or versioning)
Database
Set up PostgreSQL managed database (e.g., RDS, Cloud SQL or equivalent)
Database credentials must be stored in the cloud provider's secret management service (e.g., AWS Secrets Manager, Google Cloud Secret Manager or equivalent)
Database must not be publicly accessible (no public IP address)
Configure Highly Available (HA) prod database
Configure access policies, encryption, firewall rules
Configure point in time recovery and daily backups for test and prod.
Use your best judgement for the retention period (e.g., 7 days of logs and 30 daily backups for prod, 1 day of logs and 7 daily backups for test)
Configure DNS records (e.g., db.test-private.example.com, db.prod-private.example.com) to make sure that the database is always accessible from the same endpoint
Tools
Use the app of apps pattern in ArgoCD to install Helm charts. Usage of Terraform Helm provider is only allowed to install ArgoCD.
All other Helm charts must be installed using ArgoCD.
It's generally a good practice to keep the default namespace empty and use it only for debugging purposes. Same goes with keeping each tool in its own namespace for easier management and troubleshooting.
Feel free to do your own research and choose your preferred method.
ArgoCD
Set up ArgoCD using Helm chart
Use tools node group/pool for pods
Set up IAM permissions for ArgoCD
External Secrets
Set up External Secrets using Helm chart
Use tools node group/pool for pods
Create required IAM permissions and Cluster Secret Store
Cloud providers secret management service must be used as secret store (e.g., AWS Secrets Manager, Google Cloud Secret Manager or equivalent)
External DNS
Set up External DNS using Helm chart
Use tools node group/pool for pods
Create required IAM permissions
DNS records must be created automatically (e.g., frontend.test-public.example.com must be created automatically after Helm chart is installed)
Monitoring and Logging
Prometheus
Set up Prometheus using Helm chart
Set up Prometheus Postgres exporter using Helm chart
Use monitoring node group/pool for pods
Configure alerting rules
Configure notifications for Prometheus alerts to a messenger app of your choice (e.g., Slack, Microsoft Teams, Discord etc.)
Loki
Set up Loki using Helm chart
Use monitoring node group/pool for pods
Create required IAM permissions
Promtail/Grafana Alloy
Set up Promtail or Grafana Alloy using Helm chart
Use monitoring node group/pool for pods
Configure it to push logs to previously installed Loki instance.
Grafana
Set up Grafana using Helm chart
Use monitoring node group/pool for pods
Configure Loki and Prometheus as a data sources
Configure cloud provider as a data source (e.g., AWS CloudWatch, Google Cloud Monitoring)
Create required IAM permissions to access metrics from cloud provider
Set up dashboards, at minimum displaying following:
Kubernetes cluster metrics from Prometheus as a data source
logs from Loki as a data source (e.g., Sample application logs)
database metrics scraped by Prometheus Postgres exporter
database metrics from cloud provider (e.g., storage bucket usage)
Set up datasources and dashboards in a way that they'll automatically be available upon Grafana installation (e.g., using Helm values file)
Migration
Sample application
Create Helm charts for Sample application
Use main node group/pool for pods
Use sample-app namespace for pods
Frontend and backend must have separate Helm charts to allow independent deployment
Use the same Helm chart for all environments. The only difference should be in the Helm values file
DNS records must be created automatically by External DNS (e.g., frontend.test-public.example.com, backend.test-public.example.com)
Database credentials must be accessed from cloud provider secret management service using External Secrets
Make production frontend accessible from the root domain (e.g., https://www.example.com)
CI/CD
Gitlab and ArgoCD
ArgoCD can read Helm charts from OCI registries or git repositories. It is recommended to use OCI registry but both are commonly used. Feel free to do your own research and choose your preferred method.
Set up Gitlab CI pipeline which contains the following steps:
Run backend tests
Build Docker images for both backend and frontend and push them to private container registry in the shared account
Build Helm charts for backend and frontend and push them to private OCI registry in the shared account (optional)
Any updates to the main branch must automatically trigger the pipeline to deploy the current state of main branch to test environment
Pause the pipeline and require manual approval before deployment to prod environment
Deployment to prod environment must only be available from main branch after successful deployment to test environment
Set up ArgoCD CLI in the CI pipeline
Create a token in ArgoCD for GitLab CI and set correct permissions
argocd app get/diff/sync/wait commands can be used in the CI pipeline to deploy the application to different environments
Pipeline must provide feedback about the deployment status (e.g., if ArgoCD refresh/sync fails, the pipeline should fail)
Same Helm charts must be used for all environments. The environment-specific configuration should be in the Helm values files
Create a rollback plan for the application to restore the previous state in case of failure
Important Considerations ❗
Billing ❗❗❗Very important❗❗❗
Implement and review your billing alerts and budget.
Destroy unused resources to save costs. It might be a good idea to create some CI pipelines which can be triggered to nuke your infrastructure and rebuild it when needed. Use terraform destroy, cloud console, custom scripts, or third-party tools like aws-nuke.
IAM and Security
Always use the least privilege principle.
Resources
Start with small resources and scale up as needed to avoid unnecessary costs.
Expected Outcome 🎯
By the end of this project, you should have successfully:
Migrated the Sample application to cloud provider of your choice.
Implemented Infrastructure as Code with Terraform.
Deployed two environments: test and prod.
Set up CI/CD using GitLab, Helm charts and ArgoCD.
Set up monitoring and logging using Prometheus, Loki and Grafana.
Demonstrated understanding of key cloud concepts through practical implementation and the ability to explain your design choices.
Your final result should be a fully functional cloud infrastructure that runs your application reliably, enables scaling, and offers comprehensive monitoring and management capabilities.
Extra requirements 📚
Implement CI/CD using self-managed GitLab in the shared account.
Create DNS zone and records to make GitLab accessible
Use Terraform to create required resources for hosting your own GitLab instance. (e.g., VPC, firewall rules, VM instance etc.)
Install GitLab Community Edition (e.g., use a startup script, container, Ansible etc.)
Configure data persistence for GitLab (if GitLab VM is destroyed, there should be no data loss)
Make GitLab accessible (e.g., https://gitlab.example.com)
Increase security by making everything private except the production frontend and backend.
Configure VPN to access your private cloud resources through private IP addresses and private DNS zone (e.g., frontend.test-private.example.com)
Use managed VPN service (e.g., AWS VPN), create your own (e.g., configure a Virtual Machine with Wireguard) or use a third-party solution.
Use internal load balancers for everything except the production frontend and backend.
Use private DNS zone to access your tooling and monitoring (e.g., GitLab, Prometheus, Grafana, ArgoCD etc.)
Bonus functionality 🎁
You're welcome to implement other bonuses as you see fit. But anything you implement must not change the default functional behavior of your project.
You may use additional feature flags, command line arguments or separate builds to switch your bonus functionality on.
Useful Links 🔗
AWS Cloud Migration Guide
Google Cloud Migration Documentation
Azure Cloud Migration Center
GitLab Documentation
Terraform registry
Terraform AWS modules
Terraform Google modules
Terraform Azure modules
Helm
Grafana Helm charts
Prometheus Helm Charts
Excalidraw
What you'll learn 🧠
Cloud migration practices
Terraform for infrastructure provisioning
Helm for application deployment
GitOps with GitLab and ArgoCD
Monitoring and logging with Grafana, Prometheus and Loki
Deliverables and Review Requirements 📁
A repository with all source code and configuration files
A README file with:
Project overview
Architecture diagram
Setup and installation instructions
Usage guide
Any additional features or bonus functionality implemented
During the review, be prepared to:
Explain your code, design and cost-optimimization choices
Discuss any challenges you faced and how you overcame them
Demonstrate:
CI/CD pipeline in action
monitoring and logging dashboards in action
Prometheus alerts in action
application's functionality
application's backup, rollback and recovery process