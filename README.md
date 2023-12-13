# EKS Cluster, Addons and Sample app using Terraform

Create OIDC Resources (Provider and Role) to use temporary credentials for GA to access your AWS account:

1. Make sure you are logged on to your AWS account locally.
2. Go to ./ga-oidc.
3. Update variable "subjects" in the terraform.tfvars to your repo.
3. Init/Apply terraform.
4. This will create required OIDC resources for GA to use temorary credentials to access AWS.
5. Update "role-to-assume" var in all the GA workflows to have you own account 

Create EKS Cluster:

1. Edit ./eks-infra/main.tf "instance_types" to the node type you want.Currently it is t3.medium.
2. Run the Github Action called "Create Cluster". This will:Create EKS Cluster, Managed NodeGroups, VPC and KMS Key.Other required resources will also be created.
3. This Action will also install Calico CNI.

Install Kubernetes Add-Ons

1. Edit ./eks-apps/delete_helm_addons.tfvars to set vars for the required add-ons to true.Note that there are many more Add-ons available to be installed. Look at the code to see which ones can be enabled and add vars as needed.
2. Run the Github Action called "Istall Helm Addons". This will install the configured addons to the cluster.

Install Sample App

1. Run the Github Action called "Install Sample App".This will install a sample microservices app provided by Google.

Access the Sample App

1. Update kubeconfig using command below:
    aws eks update-kubeconfig --name eks-cluster --region eu-west-1 --role-arn arn:aws:iam::955210728575:role/ex-iam-github-oidc
2. Port forward using command below:
    kubectl port-forward svc/frontend-external -n app 8081:80
3. Go to http://localhost:8081/ in browser.

Deletion:

Uninstall Sample App

1. Run the Github Action called "Delete Sample App".This will delete the sample app.

Uninstall Kubernetes Add-ons

1. Edit ./eks-apps/delete_helm_addons.tfvars to include the vars for add-ons that need to be deleted.This can also be used to delete the add-ons selectively.Just be aware of any dependencies.
2. Run the Github Action called "Delete Helm Addons". This will install the configured addons from the cluster.
3. Sometimes the namespace for a particular add-on can be stuck in "terminating" state. If this happens run following command:
    sh scripts/finalizer.sh <namespace that is stuck>
4. Once this is done the GA workflow will complete.

Delete the EKS Cluster.

1. Run the Github Action called "Delete Cluster". This will delete EKS Cluster, Managed NodeGroups, VPC, KMS Key and any other resources that were created.


TBC:

1. Variabilize account_id in GA workflows.
2. Variabilize instance_types.
3. Create an ingress to access sample app.
4. Use Argocd to install app. Had tried it for add-ons but that didn't work very well so decided to do that using helm.
5. Check reason for add-on namespace stuck in "terminating" state for some add-ons.
6. Any clean-up or refactor of code to use node-groups.
7. Use load generator for the sample app.
8. Enable Istio/Kiali.
9. Enable other important add-ons.
10. Set up monitoring, tracing and metrics.


