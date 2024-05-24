# Dreamcanvas

Dreamcanvas is a project to deploy self-hosted AI, specifically Stable Diffusion, in the cloud using AWS EKS. This repository contains all necessary configurations, including Docker, Kubernetes, Helm charts, and Terraform scripts to set up and manage the infrastructure.

![website.png](images%2Fwebsite.png)

![generated_image.png](images%2Fgenerated_image.png)

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configurations](#configurations)

## Prerequisites
Before you begin, ensure you have the following installed:
- [Docker](https://www.docker.com/)
- [Kubernetes](https://kubernetes.io/)
- [Helm](https://helm.sh/)
- [Terraform](https://www.terraform.io/)
- [AWS CLI](https://aws.amazon.com/cli/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Installation
Follow these steps to set up and run the project.

### 1. Clone the Repository
```bash
git clone https://github.com/semperfitodd/dreamcanvas.git
cd dreamcanvas
```

### 2. Build the React.js site
``` bash
cd static-site
npm install
npm run build
```

### 3. Configure Terraform
Update the terraform/terraform.tfvars file with your specific configurations:

```hcl
company = "dreamcanvas"
domain = "example.com"
openvpn_instance_type = "t3.micro"
region = "us-east-1"
```
Additionally, update the `backend.tf` as needed.

### 4. Apply Terraform Configuration
This will set up the entire infrastructure including the static website files.

```bash
cd terraform
terraform init
terraform apply
```
### 5. Build and Push Docker Images
Login to ECR
```bash
aws ecr get-login-password --region <AWS_REGION>| docker login --username AWS --password-stdin <AWS_ACCOUNT>.dkr.ecr.<AWS_REGION>.amazonaws.com
```

Add your Huggingface token to `docker/stablediffusion/token.txt`, then build and push the Docker image to ECR.
```bash
cd docker/stablediffusion
docker build -t <AWS_ACCOUNT>.dkr.ecr.<AWS_REGION>.amazonaws.com/dreamcanvas_stablediffusion:0 .
docker push <AWS_ACCOUNT>.dkr.ecr.<AWS_REGION>.amazonaws.com/dreamcanvas_stablediffusion:0

Build the flask API
cd docker/flask
docker build -t <AWS_ACCOUNT>.dkr.ecr.<AWS_REGION>.amazonaws.com/dreamcanvas_flaskapp:0 .
docker push <AWS_ACCOUNT>.dkr.ecr.<AWS_REGION>.amazonaws.com/dreamcanvas_flaskapp:0
```

### 6. Setup OpenVPN (optional)
* Use SSM to `Connect` to the instance terminal
    ```bash
    sudo -i
    ```
* Run through OpenVPN setup
* Record initial admin password
* Setup LetsEncrypt certificate for SSL (optional)
* Login to admin console
* Setup new users (optional)
* Add VPC CIDR block under
  
  `Specify the private subnets to which all clients should be given access (one per line):`
* Save changes and restart server

![openvpn.png](images%2Fopenvpn.png)

### 7. Deploy ArgoCD
Connect to your EKS cluster and deploy ArgoCD. Everything is nested, so running the following in the `master` directory will deploy everything:
```bash
cd k8s/master
helm template . | kubectl apply -f -
```
ArgoCD will manage itself and other applications.

![argocd.png](images%2Fargocd.png)

## Configurations
* **Docker:** Ensure `token.txt` contains your Huggingface token.
 
* **Kubernetes:** `values.yaml` in both master and application directories need to be updated with your configurations.

* **Terraform:** `terraform.tfvars` is the primary file to configure your company, domain, instance type, and region.
