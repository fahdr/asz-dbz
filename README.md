## Info
App name: dbzapp

### For SRE candidate

### Description:
The code in this repository consists of terraform code, helm charts and a docker file. 
Features:
 - EKS
 - Cluster Autoscaling
 - Mixed instance group with multiple istance types (t2.small,t2.medium) with ondemand and spot instances
 - Horizontal Pod Autoscaling
 - Network Load balancer
 - Application Load balancer
 - Cluster level Monitoring ( EKS and worker nodes along with application) with persistent storage
 - Alerting (with email and slack integration)

### Quick Setup

#### Pre-requisites
You need the following to install this setup. Instructions on how to install are provided below
- AWS account (exceeds free-tier limitation)
- terraform cli 
- aws cli
- kubectl client
- helm
- git
- unix based machine (linux or mac)- terraform runs some scripts in shell during installation

### Pre-requisites Installation steps

#### Install aws cli
[Download and insall AWS CLI](https://aws.amazon.com/cli/)

Once installed configure aws cli to use your credential and to login

```bash
aws configure
```
Enter your access key. You can generate it from here [Get access key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys)

#### Install terraform
[How to install terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

#### Install kubectl client
[How to install kubectl](https://kubernetes.io/docs/tasks/tools/)

#### Install helm
[How to install helm](https://helm.sh/docs/intro/install/)

#### Install git
[How to install git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

# Installation

## Clone repository

```bash
git clone https://github.com/fahdr/asz-dbz.git
```

## Setup AWS Environment

cd into the directory

```bash
cd asz-dbz/terraform
```

Initialize terraform. This retieves the providers listed

```bash
terraform init
```
#### Install the Environment. 

Set the right variables
Open terraform.tfvars in an editor and change these values. 
The installation runs without having to change any values

   - Set your domain name for ingress. You can leave this as it is if you dont have one:
    ```bash
    dns_base_domain = "eks.daysofdevops.com"
    ```
   - Set the instance types. 
     ```bash
     asg_instance_types  = ["t2.small", "t2.micro", "t2.nano"]
     ```
   - Set auto scaling values.
     ```bash
     autoscaling_minimum_size_by_az = 1  # Minimum number of instances. Will by multipled by number of availibilty zones during installation
    autoscaling_maximum_size_by_az = 10 # Minimum number of instances. Will by multipled by number of availibilty zones during installation
    autoscaling_average_cpu  = 30 # Threshold for autoscaling
    ```

Run the terraform installation

```bash
terraform apply
```

After showing you the resources to be created it will ask for confirmation. type yes to continue.

This should install 58 changes in total. (Not all are resources)

Once completed you will be shown the result.

#### configure kubectl to point to your cluster

Run this command. change the region in the command if you have changed the region during installation

```bash
aws eks --region us-west-2 update-kubeconfig --name sre_candidate
```

#### Install Monitoring

cd into the monitor folder

```bash
cd ../helm/monitor
```
#### Edit variables before installation

Edit values.yaml file. You only need to change the domain name in the extra scrapeConfig section.

```yaml
static_configs:
       - targets:
         - a220d924eef9c4ac78f3db3f7d17b1fd-1566615617.us-west-2.elb.amazonaws.com
```
 #### This has to be changed in order for the blackbox exporter to probe external access. You can add the domain managed by route53 OR find the DNS name of the load balancer and add it here

#### Add repos for helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```
#### Build dependency

```bash
helm dependency build
```
 #### Run the installation:

 ```bash
 helm install monitor .
 ```
* monitor is the name of the release and can be changed

### Install the app

cd into the app folder

```bash
cd ../dbzapp
```

#### Change variables

Edit values.yaml file. You only need to change one. This is a good oppurtunity to change others, like hpa settings

```yaml
Ingress:
  #host: dbz.eks.daysofdevops.com
  # change this value to route53 configured domain or the dns name of load balancer
  host: a592f88102ee54c31b8543c7234c1e7f-1829126277.us-west-2.elb.amazonaws.com
```
### Run the installation

```bash
helm install dbzapp
```
* monitor is the name of the release and can be changed

If everything goes well you should have everything working

#### End of installation

### Prometheus dashboard

```bash
kubectl port-forward svc/monitor-prometheus-server 9090:80
```
You can now view the dashboard in your browser using localhost port 9090
[http://localhost:9090](http://localhost:9090)

#### Alerting

You can see that there are 3 alerts in the Alerts menu of the dashboard

- If more than 100 4xx status_code is recieved in 1 hour
- If more than 50 5xx status_code is recieved in 5 hour
- if check.txt check fails



### Details of Installation

#### TERRAFORM

1. ##### VPC (Network) - 
Using a vpc makes things more cleaner for this demo. Destroys everything once complete
 - Private subnets - No of subnets depend on Availabilty zones. The script looks for zones and creates a list per zone
 - Public subnets - No of subnets depend on Availabilty zones. The script looks for zones and creates a list per zone
 - NAT gateway - Only one as more are not needed for this demo. This could create a single point of failure in production, since we are creating a NAT Gateway in one AZ only.
 
2. ##### EKS cluster - 
EKS cluster with Autoscaling using Kuberentes v1.19 along with cluster CA certificates
 - Launch template - Creates instace times the availability zone. EKS needs atleast two availability zones. The launch template can used mixed instance and can request spot instace when the base on-demand threshold is reached.The decision is based on pricing. 
 - Autoscaling policy - The cluster auto scales when Average Cpu utilization meets the definable value
 - Spot termiation handler - Ensures control plane responds correctly when instance goes down

 3. ##### Ingress - 
 Creates a ELB on aws and ALB using nginx. Though we have better ways of handling load balancer on aws in recent days. AWS Load balancer can now handle both Layer 7 and layer 4, there is still enough benifits using AWS ELB- NGINX ALB
 [Why nginx](https://www.nginx.com/blog/aws-alb-vs-nginx-plus/) 

  - Route53 Zone - Creates a hosted zone with the domain provided. Initial plan was to read value from an already present zone and use for ingress, but in the spirit of automation decided to create the zone.
  ###### This requires a domain managed by AWS route53. You can do this by either pointing your domain to the route53 aname serversor registering domain on route53 itself [How to manage your domain using AWS](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html)
  ##### PRO TIP: We can use the default DNS name provided in terraform.tfvars for our purposes

  - AWS ACM Certificate - SSL certificate to handle tls termination at the load balancer
  - Certificate Validation - The certificate issuing authority needs to validate your ownership for the domain. If route53 is managing your domain, then a CNAME record is added to the records. If your domain is not managed by AWS then you wiil have to add this manually. 
  [How to avalidate certificate](https://aws.amazon.com/blogs/security/easier-certificate-validation-using-dns-with-aws-certificate-manager/)
  ###### Deployment will fail if certificate is not validated
  ###### PRO TIP: The domain eks.daysofdevops.com is validated and can be used in the variables section for smooth deployment

  5. ##### Ingress gateway - Ingress controller is handled by nginx as mentioned above. The is deployed with helm using the helm_release resource in terraform, to keep infrastructure code in a single source

  #### HELM

  1. dbzapp - 
  Runs a deployment with a multi container pod. The application itself and a side car container to export nginx logs
  This is a simple app that returns a status code depending on the page requested.
     - example.com/check.txt returns status_code 200 with "Its working!!!" as a string in the body
     - example.com/404 returns error code  400 and a page with "Not Found" as a string in the body
     - example.com/403 returns error code  403 and a page with "Forbidden" as a string in the body
     - example.com/500 returns error code  500 and a page with "Application error" as a string in the body
     - example.com/502 returns error code  502 and a page with "Bad Gateway" as a string in the body
   The app is served using nginx and is present in the same container.
   The side car conatiner reads logs from the app container and formats it for prometheus exposing /metrics 
   This app contains the following templates:
      * deployment.yaml - Deployment for Application and metrics exporter (sidecar container)
        - Adds annotations for prometheus discovery
        - adds app container
        - adds sidecar container
        - exposes ports
        - adds resources for cpu and memory
        - mounts configmap for use by sidecar container
      * exporter-config.yaml - config file used by log exporter
        - Listens to syslogs for logs
        - sets format to match format of nginx logs
        - serves /metrics
      * hpa.yaml - Horizontal Pod Autoscaling
        - sets minimum and maximum replicas
        - Defines Cpu utilization above which the pods should scale
      * metrics-server.yaml - vanilla metrics server required by HPA
      * service.yaml - Creates a service to expose the application
        - defines port 80 (http) for application 
        - defines port 4040 for metrics collection for prometheus
      * ingress.yaml - Sets ingress rules for application
        - Sends all incoming traffic to the backend
        - Defines backend to route traffic to application service
        - Defines host which is the domain name it should listen to.
        ##### This shoud be the domain name configured with route53. If the domain name isnot configured no traffic will pass through
        ##### PRO TIP: You can use the default aws domain name (DNS Name) given to the load balancer found in AWS console if you dont have a vaild domain
 
    * values.yaml - values file with default values for the installation
        Detailed comments are provided for each value within the values.yaml file

### MONITOR
 Contains charts for deploying the monitoring stack
  Installs 
    * Prometheus
    * Node exporter
    * Alert manager
    * Blackbox exporter

  This chart does not contain any custom templates. It only defines dependencies to install monitoring related pods
  
  - values.yaml
  Defines the default values to set scrape_config, service discovery and alerts. these values are appended to the prometheus.yml file

  Defined values for alerts
    - Alert if 4xx error code are generated 100 times in 1 hour
    - alert if 5xx codes are generated 50 times in 5 minutes
    - Alert if /check.txt does not return status_code of 200
    - Sets scrape_config to probe blackbox container for probing the app
 ##### New alerts can be set here if needed 

 ##### Docker
 ###### This folder is not needed for deployment and is here only for reference
 Contains the dockerfile used to build the image nginx configuration file and the html files for serving the pages



