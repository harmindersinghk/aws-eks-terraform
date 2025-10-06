import os
import sys
from graphviz import Digraph

# Create a new directed graph
dot = Digraph(comment='EKS Terraform Architecture', format='png')

# Add nodes for main components
dot.node('github', 'GitHub Actions')
dot.node('oidc', 'GitHub OIDC Provider')
dot.node('oidc_role', 'OIDC Role')
dot.node('vpc', 'VPC (10.0.0.0/16)')
dot.node('igw', 'Internet Gateway')
dot.node('nat', 'NAT Gateway')
dot.node('public', 'Public Subnets')
dot.node('private', 'Private Subnets')
dot.node('intra', 'Intra Subnets')
dot.node('kms', 'KMS Key')
dot.node('eks', 'EKS Control Plane')
dot.node('blue_ng', 'Blue Node Group')
dot.node('green_ng', 'Green Node Group (SPOT)')
dot.node('separate_ng', 'Separate Node Group')
dot.node('addons', 'Kubernetes Add-ons')
dot.node('app', 'Sample App (Online Boutique)')
dot.node('users', 'Developers')

# Add edges to show relationships
dot.edge('github', 'oidc')
dot.edge('oidc', 'oidc_role')
dot.edge('oidc_role', 'eks')
dot.edge('vpc', 'igw')
dot.edge('vpc', 'public')
dot.edge('vpc', 'private')
dot.edge('vpc', 'intra')
dot.edge('igw', 'public')
dot.edge('public', 'nat')
dot.edge('nat', 'private')
dot.edge('kms', 'eks')
dot.edge('intra', 'eks')
dot.edge('eks', 'blue_ng')
dot.edge('eks', 'green_ng')
dot.edge('eks', 'separate_ng')
dot.edge('private', 'blue_ng')
dot.edge('private', 'green_ng')
dot.edge('private', 'separate_ng')
dot.edge('eks', 'addons')
dot.edge('blue_ng', 'app')
dot.edge('green_ng', 'app')
dot.edge('users', 'igw')

# Save and render the graph
dot.render('eks_architecture', directory='/Users/Harminder/aws-eks-terraform/generated-diagrams', cleanup=True)
print("Diagram generated at: /Users/Harminder/aws-eks-terraform/generated-diagrams/eks_architecture.png")
