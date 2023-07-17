provider "aws" {
  region = "eu-west-1"
}

##################
# Terraform state
##################

data "local_file" "tfstate" {
  filename = "../eks-infra/terraform.tfstate"
}

module "tfstate" {
  source = "../eks-components/modules/cost.modules.tf"

  content = data.local_file.tfstate.content
}

data "terraform_remote_state" "local_state" {
  backend = "local"

  config = {
    path = "../eks-infra/terraform.tfstate"
  }
}

module "tfstate_with_terraform_remote_state" {
  source = "../eks-components/modules/cost.modules.tf"

  content       = file(data.terraform_remote_state.local_state.config.path)
  filename_hash = "something"
}

#################
# Terraform plan
#################

data "local_file" "plan" {
  filename = "../eks-infra/jsonout.json"
}

module "plan" {
  source = "../eks-components/modules/cost.modules.tf"

  content = data.local_file.plan.content
}
