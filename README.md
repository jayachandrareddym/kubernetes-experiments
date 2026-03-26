diff --git a/README.md b/README.md
index e0e3dfc9d8b5063ff11d2f8de6f45086416dc422..ef28a214f47e3a0763a56af96eb149bdb67f6b92 100644
--- a/README.md
+++ b/README.md
@@ -1,2 +1,138 @@
-# kubernetes-experiments
-created for k8s experiments 
+# Low-Cost EKS on AWS with Terraform + GitHub Actions
+
+This repository provisions a **cost-conscious Amazon EKS cluster** and deploys a simple test application exposed through the **NGINX Ingress Controller**.
+
+It includes:
+- Terraform for infrastructure + Kubernetes resources
+- GitHub Actions pipelines for:
+  - `plan` first
+  - **manual approval** before `apply`
+  - **manual approval** before `destroy`
+
+> ⚠️ Important: EKS control plane pricing still applies. This setup reduces worker-node cost with Spot and small instance types, but it is **not fully free-tier**.
+
+## Architecture
+
+- VPC with public/private subnets across 2 AZs
+- EKS cluster
+- Managed node group using:
+  - Spot capacity
+  - small/freetier-friendly instance types (`t3.micro`, `t3.small`)
+- NGINX Ingress Controller (Helm)
+- Test app (`echoserver`) + Service + Ingress
+
+## Repository layout
+
+- `terraform/` Terraform code for AWS + EKS + app
+- `.github/workflows/terraform-plan-apply.yml` plan then approved apply (main branch only)
+- `.github/workflows/terraform-destroy.yml` approved destroy (main branch only + DESTROY confirmation)
+
+## Prerequisites
+
+1. AWS account + IAM user/role for CI
+2. GitHub repository with these secrets:
+   - `AWS_ROLE_TO_ASSUME` (recommended for OIDC)
+   - `AWS_REGION` (e.g. `us-east-1`)
+3. GitHub Environment named `production` with required reviewers for approval gates
+4. Terraform state backend (recommended S3 + DynamoDB lock)
+
+## Configure Terraform variables
+
+Create `terraform/terraform.tfvars` (example, optional for CI if defaults are enough):
+
+```hcl
+aws_region           = "us-east-1"
+cluster_name         = "lowcost-eks"
+vpc_cidr             = "10.0.0.0/16"
+private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
+public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
+node_min_size        = 1
+node_desired_size    = 1
+node_max_size        = 2
+```
+
+## Local workflow (optional)
+
+```bash
+cd terraform
+terraform init
+terraform fmt -check
+terraform validate
+terraform plan -out=tfplan
+terraform apply tfplan
+```
+
+## GitHub Actions workflow behavior
+
+### 1) Plan + approved apply
+- Trigger: `workflow_dispatch`
+- Runs only when the workflow is started from the configured `target_branch` (default: `main`).
+- Job 1 runs `terraform plan` (uses `tfvars_file` only when provided) and uploads plan artifact.
+- Job 2 (`apply`) requires approval through the `production` environment.
+- After approval, plan artifact is downloaded and applied.
+
+### 2) Approved destroy
+- Trigger: `workflow_dispatch`
+- Runs only when started from `target_branch` (default: `main`) **and** `confirm_destroy` is exactly `DESTROY`.
+- Job 1 creates a destroy plan (uses `tfvars_file` only when provided).
+- Job 2 (`destroy`) requires approval through the `production` environment.
+- After approval, destroy plan is applied.
+
+## Operational notes
+
+- EKS module is configured with `create_cloudwatch_log_group = false` to avoid Terraform failures when the cluster log group already exists from previous/partial runs.
+
+## Connect to the EKS cluster
+
+After `apply` succeeds, configure kubeconfig locally:
+
+```bash
+aws eks update-kubeconfig --region us-east-1 --name lowcost-eks
+kubectl config current-context
+kubectl get nodes
+```
+
+> Replace region/cluster name if you changed `aws_region` or `cluster_name` values.
+
+## Test the echo application
+
+1. Check that ingress-nginx and demo app are running:
+
+```bash
+kubectl get pods -n ingress-nginx
+kubectl get pods -n demo
+kubectl get svc -n ingress-nginx ingress-nginx-controller
+kubectl get ingress -n demo
+```
+
+2. Get the ingress controller external endpoint:
+
+```bash
+kubectl get svc -n ingress-nginx ingress-nginx-controller   -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
+```
+
+3. Send a test request to echo app:
+
+```bash
+export INGRESS_HOST=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
+curl -i "http://${INGRESS_HOST}/"
+```
+
+You should receive an HTTP response from `ealen/echo-server`.
+
+## Cost optimization notes
+
+- Spot worker nodes significantly reduce EC2 cost.
+- Small instance types keep baseline spend lower.
+- Keep desired capacity at `1` for testing.
+- Run destroy workflow when idle.
+- Prefer short-lived test environments.
+
+## Clean up
+
+Use the destroy workflow in GitHub Actions or locally:
+
+```bash
+cd terraform
+terraform destroy
+```
