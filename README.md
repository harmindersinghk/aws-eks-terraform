# EKS Cluster, Add-ons and Sample App using Terraform

## Prerequisites

### Create OIDC Resources

Create OIDC Provider and Role to use temporary credentials for GitHub Actions to access your AWS account:

1. Make sure you are logged into your AWS account locally.
2. Go to `./ga-oidc/`.
3. Update the `subjects` variable in `terraform.tfvars` to match your repository.
4. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform apply
   ```
5. This creates the required OIDC resources for GitHub Actions to use temporary credentials.
6. Update the `role-to-assume` variable in all GitHub Actions workflows with your own account details.

### Add GitHub Actions Secret

Add your AWS account ID to your GitHub Actions secrets with the name `ACCOUNT_NUM`. This is used by GitHub Actions workflows. You do not need to add any credentials as OIDC is used for GitHub to access the AWS account.

## Setup Instructions

### Create EKS Cluster

1. Edit `./eks-infra/main.tf` and update `instance_types` to the node type you want. Currently it is set to `t3.medium`.
2. Run the GitHub Action called **"Create Cluster"**. This will:
   - Create EKS Cluster
   - Create Managed NodeGroups
   - Create VPC and KMS Key
   - Create other required resources
3. This action will also install Calico CNI.

### Install Kubernetes Add-ons

1. Choose the deployment mode you want to use for add-ons:
   - Helm-managed: edit `./eks-apps/helm_addons.tfvars`
   - ArgoCD-managed: edit `./eks-apps/enable_argocd_addons.tfvars`
2. Set the required add-on variables to `true`. Note that there are many more add-ons available than the examples shown in these tfvars files. Look at `./eks-apps/main.tf` and `./eks-components/modules/kubernetes-addons/` to see which ones can be enabled and add variables as needed.
3. Run one of these GitHub Actions:
   - **"Install Helm Addons"** to deploy add-ons directly with Terraform/Helm
   - **"Install ArgoCD Addons"** to deploy ArgoCD and let it manage the configured add-ons
4. Use only one add-on deployment path for a given set of add-ons at a time. Running the Helm workflow deploys from `helm_addons.tfvars`; running the ArgoCD workflow deploys from `enable_argocd_addons.tfvars`.

### Install Sample App

1. Run the GitHub Action called **"Install Sample App"**. This will install a sample microservices app provided by Google.

### Install DevOps AI Toolkit Stack

1. Add one or both of these GitHub Actions secrets:
   - `DOT_AI_ANTHROPIC_API_KEY`
   - `DOT_AI_OPENAI_API_KEY`
2. Run the GitHub Action called **"Install DevOps AI Toolkit Stack"** and select the `llm_api_key_secret` dropdown option for the key you want the workflow to use.
3. Use the default `enable_ingress=false` setting if your cluster does not already have an ingress controller.
4. If you enable ingress, provide valid hostnames for both `dot_ai_host` and `dot_ai_ui_host`. The workflow installs the stack from `oci://ghcr.io/vfarcic/dot-ai-stack/charts/dot-ai-stack`, enables local embeddings, and verifies the resulting pods and services.

### Install kagent

1. Add at least one of these GitHub Actions secrets:
   - `KAGENT_OPENAI_API_KEY`
   - `OPENAI_API_KEY`
2. Run the GitHub Action called **"Install kagent"**.
3. Select the `openai_api_key_secret` dropdown option for the secret you want exposed to the install as `OPENAI_API_KEY`.
4. Choose the `profile` dropdown option:
   - `demo` installs the demo profile with preloaded agents and MCP tools.
   - `minimal` installs a leaner base setup.
5. The workflow installs kagent on the existing cluster via the `kagent install` CLI flow from the quickstart and then verifies the resulting pods and services in the selected namespace.

### Access the Sample App

1. Create an env var using the command below: 
   ```bash
   export ACCOUNT_NUM="<your AWS accounr number>"
   ```
2. Update kubeconfig using the command below:
   ```bash
   aws eks update-kubeconfig --name eks-cluster --region eu-west-1 --role-arn arn:aws:iam::${ACCOUNT_NUM}:role/ex-iam-github-oidc
   ```
3. Port forward using the command below:
   ```bash
   kubectl port-forward svc/frontend-external -n app 8081:80
   ```
4. Go to [http://localhost:8081/](http://localhost:8081/) in your browser.

## Load Testing

The project includes a comprehensive Locust-based load testing solution that simulates realistic user behavior on the Online Boutique e-commerce application.

### Prerequisites for Load Testing

Before running load tests, ensure:
1. **EKS cluster is running** (created via "Create Cluster" workflow)
2. **Sample app is deployed** (via "Install Sample App" workflow)
3. **kubectl is configured** to access your cluster:
   ```bash
   aws eks update-kubeconfig --name eks-cluster --region eu-west-1 --role-arn arn:aws:iam::{$ACCOUNT_NUM}:role/ex-iam-github-oidc
   ```

### Option 1: Automated Load Testing (Recommended)

Run load tests via GitHub Actions for fully automated testing:

1. **Navigate to GitHub Actions**:
   - Go to your repository → **Actions** tab
   - Select **"Run Load Test"** workflow

2. **Configure Test Parameters**:
   - **Users**: Number of concurrent users (default: 50)
   - **Spawn Rate**: Users spawned per second (default: 2)
   - **Duration**: Test duration (examples: `10m`, `1h`, `30s`)
   - **Test Type**: 
     - `normal`: Standard load (50 users, 2/sec)
     - `stress`: High load (200 users, 10/sec)
     - `spike`: Sudden traffic spike (500 users, 50/sec)
   - **Cleanup**: Auto-remove Locust after test (recommended: `true`)

3. **Start the Test**:
   - Click **"Run workflow"**
   - Monitor progress in the Actions tab
   - View real-time logs and results

4. **Review Results**:
   - Download test artifacts (CSV files, HTML reports)
   - Check the "Performance analysis" step for key metrics
   - Results are retained for 30 days

### Option 2: Manual Load Testing

For interactive testing and custom scenarios:

#### Step 1: Deploy Locust Infrastructure
```bash
# Deploy Locust master and worker pods
./load-testing/scripts/deploy-locust.sh deploy

# Check deployment status
./load-testing/scripts/deploy-locust.sh status
```

#### Step 2: Access Locust Web UI

**Option A: LoadBalancer (if available)**
```bash
# Get the external URL (may take a few minutes)
kubectl get service locust-master -n load-testing
# Use the EXTERNAL-IP:8089 in your browser
```

**Option B: Port Forward (always works)**
```bash
# Forward local port 8089 to Locust master
kubectl port-forward service/locust-master 8089:8089 -n load-testing

# Open http://localhost:8089 in your browser
```

#### Step 3: Configure and Run Test

1. **Open Web UI**: Navigate to `http://localhost:8089` (or LoadBalancer URL)

2. **Set Parameters**:
   - **Number of users**: Start with `50` for initial testing
   - **Spawn rate**: Use `2` users per second
   - **Host**: Should be pre-filled as `http://frontend-external.app.svc.cluster.local`

3. **Start Test**: Click **"Start swarming"**

4. **Monitor Results**:
   - **Statistics**: View real-time request stats, response times, failures
   - **Charts**: Monitor RPS, response times, and user count over time
   - **Failures**: Check any failed requests and error details
   - **Download Data**: Export CSV or HTML reports

#### Step 4: Cleanup
```bash
# Remove Locust deployment
./load-testing/scripts/deploy-locust.sh cleanup
```

### Load Testing Scenarios

The Locust tests simulate realistic e-commerce user behavior:

- **Browse homepage and products** (most common)
- **Search for items** using realistic terms
- **Add products to cart** with random quantities
- **Complete checkout process** with test payment data
- **Change currency preferences**
- **View product recommendations**
- **Admin health checks** (monitoring simulation)

### Understanding Test Results

**Key Metrics to Monitor**:
- **RPS (Requests Per Second)**: Application throughput
- **Response Time**: Average, min, max response times
- **Failure Rate**: Percentage of failed requests (should be <5%)
- **Concurrent Users**: Number of active simulated users

**Performance Thresholds**:
- ✅ **Good**: <2s average response time, <5% failure rate
- ⚠️ **Warning**: 2-5s response time, 5-10% failure rate  
- ❌ **Poor**: >5s response time, >10% failure rate

### Troubleshooting Load Tests

**Common Issues**:

1. **"Online Boutique not found"**:
   ```bash
   # Verify the sample app is deployed
   kubectl get service frontend-external -n app
   ```

2. **High failure rates**:
   ```bash
   # Check application health
   kubectl get pods -n app
   kubectl logs deployment/frontend -n app
   ```

3. **Locust pods not starting**:
   ```bash
   # Check pod status and logs
   kubectl get pods -n load-testing
   kubectl logs deployment/locust-master -n load-testing
   ```

4. **Cannot access Web UI**:
   ```bash
   # Use port-forward as fallback
   kubectl port-forward service/locust-master 8089:8089 -n load-testing
   ```

### Advanced Load Testing

For detailed configuration, custom scenarios, and advanced usage, see the comprehensive guide: [load-testing/README.md](load-testing/README.md)

**Local Development**:
```bash
# Test Locust configuration locally
./load-testing/scripts/local-test.py
```

**Custom Test Scenarios**:
- Modify `load-testing/locust/locustfile.py` for custom user behavior
- Adjust worker count: `kubectl scale deployment locust-worker --replicas=5 -n load-testing`
- Create environment-specific configurations

## Cleanup Instructions

### Delete Sample App

1. Run the GitHub Action called **"Delete Sample App"**. This will delete the sample app.

### Delete Kubernetes Add-ons

1. Edit `./eks-apps/delete_helm_addons.tfvars` to include the variables for add-ons that need to be deleted. This can also be used to delete the add-ons selectively. Just be aware of any dependencies.
2. Run the GitHub Action called **"Delete Helm Addons"**. This will remove the configured add-ons from the cluster.
3. Sometimes the namespace for a particular add-on can be stuck in "terminating" state. If this happens, run the following command:
   ```bash
   sh scripts/finalizer.sh <namespace that is stuck>
   ```
4. Once this is done, the GitHub Actions workflow will complete.

### Delete ArgoCD-managed Kubernetes Add-ons

1. Edit `./eks-apps/delete_argocd_addons.tfvars` to set the ArgoCD-managed add-ons you want removed to `false`. Keep `enable_argocd = true` and `argocd_manage_add_ons = true` so ArgoCD remains installed while it prunes the selected add-ons.
2. Run the GitHub Action called **"Delete ArgoCD Addons"**. This will remove the configured ArgoCD-managed add-ons from the cluster.
3. Sometimes the namespace for a particular add-on can be stuck in "terminating" state. If this happens, run the following command:
   ```bash
   sh scripts/finalizer.sh <namespace that is stuck>
   ```
4. Once this is done, the GitHub Actions workflow will complete.

### Delete the EKS Cluster

1. Run the GitHub Action called **"Delete Cluster"**. This will delete the EKS Cluster, Managed NodeGroups, VPC, KMS Key, and any other resources that were created.

## Next Steps

1. Variabilize `instance_types`.
2. Create an ingress to access sample app.
3. Use ArgoCD to install app. Had tried it for add-ons but that didn't work very well so decided to do that using Helm.
4. Check reason for add-on namespace stuck in "terminating" state for some add-ons.
5. Clean-up or refactor of code to use node-groups.
6. Use load generator for the sample app.
7. Enable Istio/Kiali.
8. Enable other important add-ons.
9. Set up monitoring, tracing and metrics.

## References

This repository uses open source code. Please see the links below:

- [Terraform AWS EKS Module](https://github.com/terraform-aws-modules/terraform-aws-eks)
- [AWS EKS Blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)
- [Google Cloud Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo)
