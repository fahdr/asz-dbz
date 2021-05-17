#Network vars
cluster_name            = "sre_candidate" # name of the cluster
name_prefix             = "dbz"
main_network_block      = "10.0.0.0/16"
subnet_prefix_extension = 4
zone_offset             = 8

#eks vars

asg_instance_types                       = ["t2.small", "t2.micro", "t2.nano"] # Type of instance for autoscaling
autoscaling_minimum_size_by_az           = 1  # Minimum number of instances. Will by multipled by number of availibilty zones during installation
autoscaling_maximum_size_by_az           = 10 # Minimum number of instances. Will by multipled by number of availibilty zones during installation
autoscaling_average_cpu                  = 30 # Threshold for autoscaling
spot_termination_handler_chart_name      = "aws-node-termination-handler"
spot_termination_handler_chart_repo      = "https://aws.github.io/eks-charts"
spot_termination_handler_chart_version   = "0.9.1"
spot_termination_handler_chart_namespace = "kube-system"

#ingress vars
dns_base_domain               = "eks.daysofdevops.com" # domain name to use. Make sure that it is managed by AWS Route53
ingress_gateway_chart_name    = "nginx-ingress"
ingress_gateway_chart_repo    = "https://helm.nginx.com/stable"
ingress_gateway_chart_version = "0.5.2"
ingress_gateway_annotations = {
  "controller.service.httpPort.targetPort"                                                                    = "http",
  "controller.service.httpsPort.targetPort"                                                                   = "http",
  "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"        = "http",
  "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"               = "https",
  "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-connection-idle-timeout" = "60",
  "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"                    = "elb"
  "prometheus.create" = "true"
  "prometheus.port" = "9113"
}



