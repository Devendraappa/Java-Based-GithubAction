# =========================================
# OIDC PROVIDER (for IRSA)
# =========================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  depends_on      = [aws_eks_cluster.main]
}

# =========================================
# EBS CSI DRIVER IAM ROLE
# =========================================
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.project_name}-${var.env}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# =========================================
# EKS CLUSTER
# =========================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.env
  }
}

# =========================================
# NODE GROUP
# =========================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.env}-nodegroup"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.project_name}-${var.env}-nodegroup"
    Environment = var.env
  }

  depends_on = [aws_eks_cluster.main]
}

# =========================================
# ADDONS
# =========================================
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = "aws-ebs-csi-driver"
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
#   #skip_destroy                = true

#   depends_on = [
#     aws_eks_node_group.main,
#     aws_iam_role.ebs_csi_driver
#   ]

  # lifecycle {
  #   prevent_destroy = true
  # }
# }
# =========================================
# ACCESS ENTRY - DYNAMIC (Works with root / terraform user)
# =========================================
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "current_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
  depends_on    = [aws_eks_cluster.main]
}

resource "aws_eks_access_policy_association" "current_user_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.current_user]
}








# # =========================================
# # OIDC PROVIDER
# # =========================================
# data "tls_certificate" "eks" {
#   url = aws_eks_cluster.main.identity[0].oidc[0].issuer
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
#   url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
#   depends_on      = [aws_eks_cluster.main]
# }

# # =========================================
# # EBS CSI DRIVER IAM ROLE (IRSA)
# # Keep role - needed when we install addon
# # =========================================
# data "aws_iam_policy_document" "ebs_csi_assume_role" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
#     }
#   }
# }

# resource "aws_iam_role" "ebs_csi_driver" {
#   name               = "${var.project_name}-${var.env}-ebs-csi-role"
#   assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
#   role       = aws_iam_role.ebs_csi_driver.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }

# # =========================================
# # EKS CLUSTER
# # =========================================
# resource "aws_eks_cluster" "main" {
#   name     = var.cluster_name
#   version  = var.cluster_version
#   role_arn = var.cluster_role_arn

#   vpc_config {
#     subnet_ids              = var.private_subnet_ids
#     endpoint_private_access = true
#     endpoint_public_access  = true
#   }

#   access_config {
#     authentication_mode                         = "API_AND_CONFIG_MAP"
#     bootstrap_cluster_creator_admin_permissions = true
#   }

#   tags = { Name = var.cluster_name }
# }

# # =========================================
# # NODE GROUP
# # =========================================
# resource "aws_eks_node_group" "main" {
#   cluster_name    = aws_eks_cluster.main.name
#   node_group_name = "${var.project_name}-${var.env}-nodegroup"
#   node_role_arn   = var.node_role_arn
#   subnet_ids      = var.private_subnet_ids
#   instance_types  = var.node_instance_types

#   scaling_config {
#     desired_size = var.node_desired_size
#     min_size     = var.node_min_size
#     max_size     = var.node_max_size
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   tags = { Name = "${var.project_name}-${var.env}-nodegroup" }
# }

# # =========================================
# # OTHER ADDONS (keeping these)
# # =========================================
# resource "aws_eks_addon" "coredns" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "coredns"
#   depends_on   = [aws_eks_node_group.main]
# }

# resource "aws_eks_addon" "vpc_cni" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "vpc-cni"
#   depends_on   = [aws_eks_node_group.main]
# }

# resource "aws_eks_addon" "kube_proxy" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "kube-proxy"
#   depends_on   = [aws_eks_node_group.main]
# }

# # =========================================
# # TERRAFORM USER ACCESS
# # =========================================
# data "aws_caller_identity" "current" {}

# resource "aws_eks_access_entry" "terraform_user" {
#   cluster_name  = aws_eks_cluster.main.name
#   principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
#   type          = "STANDARD"
#   depends_on    = [aws_eks_cluster.main]
# }

# resource "aws_eks_access_policy_association" "terraform_admin" {
#   cluster_name  = aws_eks_cluster.main.name
#   principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

#   access_scope {
#     type = "cluster"
#   }

#   depends_on = [aws_eks_access_entry.terraform_user]
# }