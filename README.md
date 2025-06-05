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

1. Edit `./eks-apps/delete_helm_addons.tfvars` to set variables for the required add-ons to `true`. Note that there are many more add-ons available to be installed. Look at the code to see which ones can be enabled and add variables as needed.
2. Run the GitHub Action called **"Install Helm Addons"**. This will install the configured add-ons to the cluster.

### Install Sample App

1. Run the GitHub Action called **"Install Sample App"**. This will install a sample microservices app provided by Google.

### Access the Sample App

1. Update kubeconfig using the command below:
   ```bash
   aws eks update-kubeconfig --name eks-cluster --region eu-west-1 --role-arn arn:aws:iam::{$ACCOUNT_NUM}:role/ex-iam-github-oidc
   ```
2. Port forward using the command below:
   ```bash
   kubectl port-forward svc/frontend-external -n app 8081:80
   ```
3. Go to [http://localhost:8081/](http://localhost:8081/) in your browser.

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


