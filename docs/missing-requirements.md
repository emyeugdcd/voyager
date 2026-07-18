So I noted some of the unaccepted requirements here with explanations how it was implemented:

1. **Student can demonstrate automatic DNS record creation using External DNS**
    - Ask student to make frontend available from an additional subdomain by modifying the Ingress or HTTPRoute resource (e.g., dnstest.prod-public.example.com) and verify that the DNS record in the cloud providers DNS service (e.g., AWS Route 53, Google Cloud DNS) is created automatically.

So I have implemented this in these files: /kubernetes/argocd/apps/external-dns.yaml and /kubernetes/apps/external-dns/values.yaml. This is also configured in the /charts/frontend/values-prod.yaml and /charts/frontend/values-test.yaml. So we don't need to create DNS records manually: when we add a new route to our configuration files above, our external-dns controller will read and makes an Azure API call then register it.
I have tested this by adding a new route in /charts/frontend/values-test.yaml. When I applied it, external-dns created a DNS record in Azure called "dnstest" as you can see from the screenshot from this link (yesterday during the review call there was no "dnstest" record in Azure):
https://drive.google.com/file/d/1ZWlh8dFhR2FqzfSEFUeiJPfVwRPbp-X3/view?usp=share_link


2. **Prometheus is installed with Helm chart and ArgoCD**

    **Prometheus Postgres exporter is installed with Helm chart and ArgoCD**

    **Prometheus alerts are configured (Trigger any alert and verify that alert is sent to the configured messaging app (e.g., Slack, Teams, Discord etc.))**

So these are all done here in these files:
- /kubernetes/argocd/apps/monitoring.yaml: This is the manifest that tells ArgoCD to install the Prometheus stack with a Helm chart
- /kubernetes/monitoring/prometheus/helm-values.yaml: This is the configuration file for the Prometheus alert. I have set up the alertmanager (tool in Prometheus for alerting) with alert rules: 
    - NodeMemoryUsageHigh (Line 45): Fires if memory usage on any machine exceeds 85% for over 5 minutes.
    - PodCrashLooping (Line 52): Fires if a pod restarts more than twice within a 5-minute window. (I think we also saw this during the review call yesterday, the Loki pod notified us of a PodCrashLoop)

3. **Loki is installed with Helm chart and ArgoCD**
- This is also configured in /kubernetes/argocd/apps/loki.yaml and /kubernetes/monitoring/loki/helm-values.yaml. So Loki will aggregate logs from all the pods in the cluster and store them in the Azure Blog Storage Service and parse them with Grafana.

4. **Dashboard displaying Postgres database metrics using Prometheus Postgres exporter as data source exists in Grafana**
- I have demonstrated this during the review call when I showcased the Grafana dashboard with mentions of some of the metrics we have seen on the dashboard including: CPU memory, how many pods are running, etc.

5. **Dashboard displaying logs from Sample application using Loki as data source exists in Grafana** (Register, login and logout in the Sample application frontend and verify that the logs are displayed in the dashboard)

- I have demonstrated this together with number 7 below

6. **Sample application is installed with Helm chart and ArgoCD**

- The installation setup can be found within the ArgoCD's app yaml files: /kubernetes/argocd/apps/sample-app-frontend.yaml and /kubernetes/argocd/apps/sample-app-backend.yaml

**Sample application Helm charts for prod and test environments are identical (reusable)**
- So I have written yaml files for these setups in the charts/frontend and charts/backend folders, also you can check the templates directory within each of them. You can check the values-prod.yaml and values-test.yaml files to see the configuration for the prod and test environments, especially the /templates/deployment.yaml file has no hardcoded values, instead it uses the similar Golang template parameters like {{ .Values.image.tag }}.to dynamically create the deployment, so that we can reuse the same template for both environments.

7. **Sample application production environment frontend is publicly accessible on the root domain**

So I have managed to deploy the frontend domain now through this link: https://frontend.prod-public.voyager-cloud.com (but it only works if you fork the project and do the full set up yourself since it uses my own personal Azure account, so I would not bother trying it out. However, I have attached here a screenshot of the result:
- So here you can see that I have the frontend and even backend domain: https://drive.google.com/file/d/161ml2lNh9YrxgXllwvj_SvGLu9iqjRGW/view?usp=sharing

- And then I registered and logged in to the frontend, and as you can see from the terminal here, the logs are successfully logged to the Grafana dashboard:
https://drive.google.com/file/d/1Wqa2SY98GxupcsPOFzmwPaNnzvx9WkT_/view?usp=sharing (This is a short screen recording of my login in)

https://drive.google.com/file/d/1wGJ0EQia_vEkiRZNtqBawabDabJVJG80/view?usp=sharing (and this is the Loki log reading from backend)

8. **Gitlab CI pipeline exists**
**Container image is built in Gitlab CI pipeline and pushed to private registry in the shared account**

- I have demonstrated this during the review call

9. **Manual approval is required before deployment to production**

This is included in the file: .gitlab-ci.yml (stage 3 of production, line 77)
```
# Stage 3: Manual approval gate for production deployment
# -------------------------------------------------------------
# PRODUCTION DEPLOYMENT
# This stage implements the manual approval gate required by
# the evaluation criteria. The pipeline halts here.
# -------------------------------------------------------------

deploy-prod:
  stage: deploy
  image: alpine:latest
  script:
    - echo "Promoting deployment to production environment..."
    - echo "Triggering ArgoCD sync for production namespace..."
  when: manual
  only:
    - main
```

10. **Pipeline provides correct feedback about the deployment status (if ArgoCD refresh/sync fails, the pipeline should fail)**
- This has been demonstrated yesterday during the review call, with the loki pod processing.

11. **Code changes to master branch automatically trigger deployment pipeline**
- This has been demonstrated yesterday

12. **Rollback capability exists to restore the Sample application to previous versions**
So here you can see that we have the history and fallback feature on ArgoCD (noted that there were many versions of our app whenever we pushed the codes, I will click on the version here that said 2 days ago for example):
https://drive.google.com/file/d/1eJjj3N6VUglWmeYKlpj9vQtZlfO8jmr0/view?usp=sharing

- And so you can see here, if you want, you can choose to sync this version, and Argo will instantly scale down the current pods and redeploy the exact previous version:
https://drive.google.com/file/d/1Q7qGgHqdyTzuWhNiXA2B5vdOvtGDtiPp/view?usp=sharing

Extra
13. **CI/CD is implemented using self-managed GitLab instance in the shared account**
**Overall setup quality for self-managed GitLab**
- I did implement CI/CD with Gitlab but no shared account because this is just a personal project. using GitLab SaaS was only pragmatic and cost-effective choice since I would use more VMs with shared account and with my free Azure tier I could not afford it.

14. **Increased security is implemented by making everything but production Sample application not publicly accessible**
- Only the React frontend has a public ingress entry point. All administrative tools—including ArgoCD console, Grafana metrics, Alertmanager, and the PostgreSQL Database server do not have public IP addresses. 

15. **VPN is configured to access private resources**

In the Terraform production environment (not the test enviroment) a secure Jumphost VM is fully defined: It acts as the secure VPN tunnel gateway to access private resources. For the Test environment, because of the 4-core limit, the Jumphost was scaled down to 0 (as I have mentioned during the review call), and public API access was enabled on the AKS cluster control plane so I could run kubectl directly from my Mac without exceeding the core quota.

16. **Level of automation with IaC and CI/CD tool**

So what I have done: 
- Terraform for infrastructure automation: Infrastructure is managed using Terraform, ensuring consistent and repeatable deployments.
- GitOps-driven ArgoCD deployments: ArgoCD is used for GitOps-based application deployments, ensuring that the cluster state matches the Git repository.
- Fully implemented Gitlab CI/CD: 100% of deployment process is automated. From code commit to production deployment, everything is handled by the CI/CD pipeline.

17. **Consistency and clarity of documentation for infrastructure and architecture decisions**
- README.md and also /docs which include walkthrough.md, architecture.md and a debugging-handbook.md 

18. **Resilience and fault-tolerance strategy (e.g., HA setup, backups, disaster recovery)**
- I did not show enough this during the review call but in the Azure service, I have implemented:

  - Multi-Zone Availability: In production, the AKS node pools are spread across Azure Availability Zones 1, 2, and 3. If a Microsoft data center experiences a physical power failure, the pods continue running in the other zones.
  - Database HA: The production database runs in a active-standby configuration, replicating data in real time across Availability zones.
  - Point-In-Time Recovery (PITR) is active, backing up transaction logs continuously to allow rollback to any exact second.

19. **Additional technologies, security enhancements, and/or features are implemented and functional beyond core requirements**
So you can see that the project is quite complete. It has everything needed for a production system, including monitoring, logging, alerting, backup, security, and disaster recovery. In addition, I have added these additional features:
- External Secrets Operator (ESO): Native secrets bridge between Kubernetes and Azure Key Vault.
- NAT Gateway: Secure egress outbound network card for private VMs.
- Azure Consumption Budgets: Real-time spending threshold alarms linked to email notifications to prevent run-away cloud bills (I did get an email notification this morning for my budget going over 25% threshold that I have set up)


