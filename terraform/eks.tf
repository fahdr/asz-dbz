locals {
 
  worker_groups_launch_template = [
    {
      instance_type           = "t2.small"
      root_volume_size        = "10"
      override_instance_types = var.asg_instance_types
      asg_desired_capacity    = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      asg_min_size            = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      asg_max_size            = var.autoscaling_maximum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      on_demand_base_capacity = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      on_demand_percentage_above_base_capacity = 25
      spot_instance_pools                      = 3
      kubelet_extra_args = "--node-labels=node.kubernetes.io/lifecycle=`curl -s http://169.254.169.254/latest/meta-data/instance-life-cycle`"
      public_ip               = true
    },
  ]
}

# create EKS cluster
module "eks-cluster" {
  source           = "terraform-aws-modules/eks/aws"
  version          = "15.2.0"
  cluster_name     = "${var.cluster_name}"
  cluster_version  = "1.19"
  write_kubeconfig = false
  wait_for_cluster_cmd          = "until curl -k -s $ENDPOINT/healthz >/dev/null; do sleep 4; done"

  subnets = module.vpc.private_subnets
  vpc_id  = module.vpc.vpc_id

  worker_groups_launch_template = local.worker_groups_launch_template


  

   tags = {
    "sre_candidate"  = "fahdrahman"
  }
}

# get EKS cluster info to configure Kubernetes and Helm providers
data "aws_eks_cluster" "cluster" {
  name = module.eks-cluster.cluster_id
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster.cluster_id
}

# get EKS authentication for being able to manage k8s objects from terraform
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
  version = "~> 1.2"
}

# deploy spot termination handler
resource "helm_release" "spot_termination_handler" {
  name       = var.spot_termination_handler_chart_name
  chart      = var.spot_termination_handler_chart_name
  repository = var.spot_termination_handler_chart_repo
  version    = var.spot_termination_handler_chart_version
  namespace  = var.spot_termination_handler_chart_namespace
}

# add Autoscaling policy
resource "aws_autoscaling_policy" "eks_autoscaling_policy" {
  count = length(local.worker_groups_launch_template)

  name                   = "${module.eks-cluster.workers_asg_names[count.index]}-autoscaling-policy"
  autoscaling_group_name = module.eks-cluster.workers_asg_names[count.index]
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.autoscaling_average_cpu
  }
}
