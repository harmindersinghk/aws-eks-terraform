from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EKS
from diagrams.aws.security import IAM, KMS
from diagrams.aws.network import VPC, PrivateSubnet, PublicSubnet, InternetGateway, NATGateway, RouteTable
from diagrams.aws.general import Users
from diagrams.k8s.compute import Pod, Deploy, RS
from diagrams.k8s.network import Service, Ingress
from diagrams.k8s.infra import Node
from diagrams.k8s.ecosystem import Helm
from diagrams.onprem.vcs import Github
from diagrams.onprem.network import Internet

with Diagram("EKS Terraform Architecture", show=True, direction="TB"):
    # External components
    github = Github("GitHub Actions")
    users = Users("Developers")
    
    # OIDC components
    with Cluster("GitHub OIDC"):
        oidc_provider = IAM("OIDC Provider")
        oidc_role = IAM("OIDC Role")
        github >> oidc_provider >> oidc_role
    
    # VPC and networking
    with Cluster("VPC (10.0.0.0/16)"):
        vpc = VPC("VPC")
        
        with Cluster("Availability Zones (3)"):
            # Public subnets
            with Cluster("Public Subnets"):
                public_subnets = [PublicSubnet("Public Subnet AZ1"),
                                 PublicSubnet("Public Subnet AZ2"),
                                 PublicSubnet("Public Subnet AZ3")]
            
            # Private subnets
            with Cluster("Private Subnets"):
                private_subnets = [PrivateSubnet("Private Subnet AZ1"),
                                  PrivateSubnet("Private Subnet AZ2"),
                                  PrivateSubnet("Private Subnet AZ3")]
            
            # Intra subnets (for control plane)
            with Cluster("Intra Subnets (Control Plane)"):
                intra_subnets = [PrivateSubnet("Intra Subnet AZ1"),
                                PrivateSubnet("Intra Subnet AZ2"),
                                PrivateSubnet("Intra Subnet AZ3")]
        
        # Networking components
        igw = InternetGateway("Internet Gateway")
        nat = NATGateway("NAT Gateway")
        
        # Connect networking components
        vpc >> igw
        igw >> public_subnets
        public_subnets[0] >> nat
        nat >> private_subnets
    
    # Security components
    kms_key = KMS("KMS Key\n(Secrets Encryption)")
    sg_additional = IAM("Additional Security Group")
    
    # EKS Cluster
    with Cluster("EKS Cluster (eks-cluster)"):
        eks_control_plane = EKS("EKS Control Plane")
        
        with Cluster("Node Groups"):
            blue_ng = Node("Blue Node Group\n(t3.medium)")
            green_ng = Node("Green Node Group\n(t3.medium, SPOT)")
            separate_ng = Node("Separate Node Group")
        
        # Connect control plane to node groups
        eks_control_plane >> blue_ng
        eks_control_plane >> green_ng
        eks_control_plane >> separate_ng
        
        # Connect control plane to intra subnets
        intra_subnets >> eks_control_plane
        
        # Connect node groups to private subnets
        private_subnets >> blue_ng
        private_subnets >> green_ng
        private_subnets >> separate_ng
        
        # Kubernetes Add-ons
        with Cluster("Kubernetes Add-ons"):
            addons = [
                Helm("CoreDNS"),
                Helm("Kube Proxy"),
                Helm("Metrics Server"),
                Helm("Cert Manager"),
                Helm("ArgoCD")
            ]
        
        # Sample Application
        with Cluster("Sample Application (Online Boutique)"):
            frontend = Deploy("Frontend")
            services = [
                Deploy("Cart"),
                Deploy("Catalog"),
                Deploy("Checkout"),
                Deploy("Currency"),
                Deploy("Email"),
                Deploy("Payment"),
                Deploy("Recommendation"),
                Deploy("Shipping")
            ]
            frontend_svc = Service("Frontend Service")
            
            # Connect frontend to backend services
            frontend >> Edge(color="blue") >> services
            frontend << Edge(color="green") << frontend_svc
    
    # External connections
    users >> igw
    oidc_role >> eks_control_plane
    kms_key >> eks_control_plane
    sg_additional >> blue_ng
    sg_additional >> green_ng
    sg_additional >> separate_ng
