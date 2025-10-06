#!/usr/bin/env python3
import pydot

# Create a new graph
graph = pydot.Dot("eks_architecture", graph_type="digraph", rankdir="TB")

# Define node styles
cluster_style = {
    "style": "filled",
    "color": "lightblue",
    "shape": "box"
}

aws_style = {
    "style": "filled",
    "color": "orange",
    "shape": "box"
}

k8s_style = {
    "style": "filled",
    "color": "lightgreen",
    "shape": "box"
}

# Create clusters
vpc_cluster = pydot.Cluster("vpc", label="VPC (10.0.0.0/16)", style="filled", color="lightgrey")
eks_cluster = pydot.Cluster("eks", label="EKS Cluster", style="filled", color="lightgrey")
addons_cluster = pydot.Cluster("addons", label="Kubernetes Add-ons", style="filled", color="lightgrey")
app_cluster = pydot.Cluster("app", label="Sample Application (Online Boutique)", style="filled", color="lightgrey")
oidc_cluster = pydot.Cluster("oidc", label="GitHub OIDC", style="filled", color="lightgrey")

# External components
github = pydot.Node("github", label="GitHub Actions", **aws_style)
users = pydot.Node("users", label="Developers", **aws_style)
graph.add_node(github)
graph.add_node(users)

# OIDC components
oidc_provider = pydot.Node("oidc_provider", label="OIDC Provider", **aws_style)
oidc_role = pydot.Node("oidc_role", label="OIDC Role", **aws_style)
oidc_cluster.add_node(oidc_provider)
oidc_cluster.add_node(oidc_role)
graph.add_subgraph(oidc_cluster)

# Security components
kms = pydot.Node("kms", label="KMS Key\n(Secrets Encryption)", **aws_style)
sg = pydot.Node("sg", label="Security Group", **aws_style)
graph.add_node(kms)
graph.add_node(sg)

# VPC components
igw = pydot.Node("igw", label="Internet Gateway", **aws_style)
nat = pydot.Node("nat", label="NAT Gateway", **aws_style)
public_subnets = pydot.Node("public_subnets", label="Public Subnets\n(3 AZs)", **aws_style)
private_subnets = pydot.Node("private_subnets", label="Private Subnets\n(3 AZs)", **aws_style)
intra_subnets = pydot.Node("intra_subnets", label="Intra Subnets\n(3 AZs)", **aws_style)

vpc_cluster.add_node(igw)
vpc_cluster.add_node(nat)
vpc_cluster.add_node(public_subnets)
vpc_cluster.add_node(private_subnets)
vpc_cluster.add_node(intra_subnets)
graph.add_subgraph(vpc_cluster)

# EKS components
control_plane = pydot.Node("control_plane", label="EKS Control Plane", **cluster_style)
blue_ng = pydot.Node("blue_ng", label="Blue Node Group\n(t3.medium)", **cluster_style)
green_ng = pydot.Node("green_ng", label="Green Node Group\n(t3.medium, SPOT)", **cluster_style)
separate_ng = pydot.Node("separate_ng", label="Separate Node Group", **cluster_style)

eks_cluster.add_node(control_plane)
eks_cluster.add_node(blue_ng)
eks_cluster.add_node(green_ng)
eks_cluster.add_node(separate_ng)

# Add-ons
coredns = pydot.Node("coredns", label="CoreDNS", **k8s_style)
kube_proxy = pydot.Node("kube_proxy", label="Kube Proxy", **k8s_style)
metrics_server = pydot.Node("metrics_server", label="Metrics Server", **k8s_style)
cert_manager = pydot.Node("cert_manager", label="Cert Manager", **k8s_style)
argocd = pydot.Node("argocd", label="ArgoCD", **k8s_style)

addons_cluster.add_node(coredns)
addons_cluster.add_node(kube_proxy)
addons_cluster.add_node(metrics_server)
addons_cluster.add_node(cert_manager)
addons_cluster.add_node(argocd)
eks_cluster.add_subgraph(addons_cluster)

# Sample app
frontend = pydot.Node("frontend", label="Frontend", **k8s_style)
cart = pydot.Node("cart", label="Cart", **k8s_style)
catalog = pydot.Node("catalog", label="Catalog", **k8s_style)
checkout = pydot.Node("checkout", label="Checkout", **k8s_style)
frontend_svc = pydot.Node("frontend_svc", label="Frontend Service", **k8s_style)

app_cluster.add_node(frontend)
app_cluster.add_node(cart)
app_cluster.add_node(catalog)
app_cluster.add_node(checkout)
app_cluster.add_node(frontend_svc)
eks_cluster.add_subgraph(app_cluster)

graph.add_subgraph(eks_cluster)

# Add edges
graph.add_edge(pydot.Edge(github, oidc_provider))
graph.add_edge(pydot.Edge(oidc_provider, oidc_role))
graph.add_edge(pydot.Edge(oidc_role, control_plane))
graph.add_edge(pydot.Edge(users, igw))
graph.add_edge(pydot.Edge(igw, public_subnets))
graph.add_edge(pydot.Edge(public_subnets, nat))
graph.add_edge(pydot.Edge(nat, private_subnets))
graph.add_edge(pydot.Edge(kms, control_plane))
graph.add_edge(pydot.Edge(intra_subnets, control_plane))
graph.add_edge(pydot.Edge(control_plane, blue_ng))
graph.add_edge(pydot.Edge(control_plane, green_ng))
graph.add_edge(pydot.Edge(control_plane, separate_ng))
graph.add_edge(pydot.Edge(private_subnets, blue_ng))
graph.add_edge(pydot.Edge(private_subnets, green_ng))
graph.add_edge(pydot.Edge(private_subnets, separate_ng))
graph.add_edge(pydot.Edge(sg, blue_ng))
graph.add_edge(pydot.Edge(sg, green_ng))
graph.add_edge(pydot.Edge(sg, separate_ng))
graph.add_edge(pydot.Edge(blue_ng, frontend))
graph.add_edge(pydot.Edge(frontend, cart))
graph.add_edge(pydot.Edge(cart, catalog))
graph.add_edge(pydot.Edge(catalog, checkout))
graph.add_edge(pydot.Edge(frontend_svc, frontend))

# Save the graph to a file
graph.write_png("/Users/Harminder/aws-eks-terraform/generated-diagrams/eks_architecture.png")
print("Diagram generated at: /Users/Harminder/aws-eks-terraform/generated-diagrams/eks_architecture.png")
