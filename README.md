# Tech Challenge 2 V2 — GitOps & Observability

This project builds upon the original Tech Challenge 2 implementation by modernizing the CI/CD and observability architecture while retaining the existing AWS EKS infrastructure and containerized Flask application.

Version 1 implemented a Jenkins-based CI/CD pipeline for building, pushing, and deploying the application to Amazon EKS. Version 2 evolves the architecture by introducing GitHub Actions for continuous integration, Argo CD for continuous delivery, GitOps for Kubernetes deployment management, and Prometheus and Grafana for monitoring and visualization.

## V2 Technologies

- **GitHub Actions** — Continuous Integration (CI)
- **Argo CD** — Continuous Delivery (CD)
- **GitOps** — Git-based Kubernetes desired-state management
- **Prometheus** — Metrics collection and monitoring
- **Grafana** — Metrics visualization and dashboards

## V1 Project Overview

This project demonstrates an end-to-end DevOps deployment of a containerized Python Flask application to Amazon EKS.

The environment uses Terraform for Infrastructure as Code, Docker and Amazon ECR for containerization and image storage, Kubernetes and Helm for application deployment, an AWS Application Load Balancer for public access, HPA and Cluster Autoscaler for scaling, and Jenkins for CI/CD automation.

The deployed application displays:

**Hello, World! CI/CD Deployment Successful!**

---

## Architecture

![Architecture Diagram](images/architecture-diagram.png)

```text
GitHub
   ↓
Jenkins Pipeline
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
Amazon EKS
   ↓
Helm / Kubernetes
   ↓
Application Load Balancer
   ↓
Flask Application
```

The application also uses two levels of autoscaling:

- **Horizontal Pod Autoscaler (HPA)** scales application pods based on CPU or memory utilization.
- **Cluster Autoscaler** scales the EKS worker node group based on workload demand.

---

## Technologies Used

- Python / Flask
- Docker
- GitHub
- Jenkins
- Terraform
- Amazon ECR
- Amazon EKS
- Kubernetes
- Helm
- AWS Application Load Balancer
- Metrics Server
- Horizontal Pod Autoscaler
- Cluster Autoscaler
- Siege

---

## Application

The project uses a simple Python Flask application located in the `app` directory.

### Run Locally

Install the application dependencies:

```bash
pip install -r app/requirements.txt
```

Start the application:

```bash
python app/app.py
```

Access the application at:

```text
http://localhost:5000
```

---

## Docker

The Flask application is containerized using Docker.

Build the Docker image:

```bash
docker build -t tech-challenge-2-app ./app
```

Run the container locally:

```bash
docker run -d --name tech-challenge-2-container -p 5000:5000 tech-challenge-2-app
```

The production Docker images are stored in Amazon ECR and deployed to Amazon EKS.

---

## Infrastructure as Code

Terraform provisions the AWS infrastructure required for the application.

### Infrastructure Provisioned

- Custom VPC
- Two public subnets
- Two private subnets
- Internet Gateway
- NAT Gateway
- Public and private route tables
- Amazon ECR repository
- Amazon EKS cluster
- EKS managed node group
- IAM roles and policies
- Jenkins EC2 server
- IAM/IRSA resources for Kubernetes controllers

The EKS worker nodes run in private subnets while public subnets support internet-facing resources such as the Application Load Balancer.

### EKS Node Configuration

- Instance type: `t3.small`
- Minimum nodes: `1`
- Desired nodes: `1`
- Maximum nodes: `4`

### Deploy Infrastructure

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Configure kubectl after the EKS cluster is created:

```bash
aws eks update-kubeconfig --region us-east-2 --name tech-challenge-2-eks
```

Verify the cluster:

```bash
kubectl get nodes
```

---

## Kubernetes and Helm

The application is deployed to Amazon EKS using Kubernetes and packaged using Helm.

The deployment includes:

- Kubernetes Deployment
- ClusterIP Service
- Readiness and liveness probes
- CPU and memory resource requests and limits
- Horizontal Pod Autoscaler
- Topology spread constraints
- Kubernetes Ingress

Application traffic follows:

```text
Internet
   ↓
AWS Application Load Balancer
   ↓
Kubernetes Ingress
   ↓
ClusterIP Service :80
   ↓
Flask Pods :5000
```

The AWS Load Balancer Controller monitors the Kubernetes Ingress and dynamically provisions the internet-facing Application Load Balancer.

Helm provides reusable Kubernetes templates and is also used by the Jenkins pipeline to deploy updated application versions.

---

## Kubernetes Self-Healing

Kubernetes self-healing was validated by manually deleting a running application pod.

Because the Deployment maintains a desired replica count, Kubernetes automatically detected the missing pod and created a replacement.

```text
Running Pod
    ↓
Pod Deleted
    ↓
Desired-State Mismatch Detected
    ↓
Replacement Pod Created
    ↓
Application Restored
```

This demonstrated Kubernetes' ability to maintain the desired application state without manual intervention.

---

## Autoscaling

The EKS environment supports both application-level and infrastructure-level autoscaling.

### Horizontal Pod Autoscaler

Metrics Server provides CPU and memory utilization metrics to Kubernetes.

The application HPA is configured with:

- Minimum pods: `1`
- Maximum pods: `12`
- CPU target: `50%`
- Memory target: `50%`

Topology spread constraints help distribute application replicas across available worker nodes.

### Cluster Autoscaler

Cluster Autoscaler manages the EKS managed node group.

The node group can scale between:

```text
1 → 4 worker nodes
```

A dedicated IAM role using IAM Roles for Service Accounts (IRSA) provides Cluster Autoscaler with the AWS permissions required to manage the underlying Auto Scaling Group.

---

## Load Testing

Siege was used to generate traffic against the application through the public AWS Application Load Balancer.

The test used 25 concurrent users for 2 minutes:

```bash
siege -c 25 -t 2M http://<ALB-DNS-NAME>
```

During the test:

- HPA scaled the application from `1` to `12` pods.
- Cluster Autoscaler scaled the EKS environment from `1` to `4` worker nodes.
- At peak load, 12 application pods were distributed across 4 worker nodes.
- Kubernetes began scaling the environment down after the load test ended.

This validated both pod-level and infrastructure-level autoscaling.

---

## Jenkins Server

A Jenkins server was provisioned on an AWS EC2 `t3.medium` instance using Terraform.

The Jenkins server includes:

- Jenkins
- Java
- Git
- Docker
- AWS CLI
- kubectl
- Helm

The Jenkins user was configured with Docker access and the tools required to manage the deployment.

### AWS Authentication

An EC2 IAM role and instance profile allow Jenkins to interact with AWS without storing long-lived AWS access keys on the server.

Jenkins was granted the required access to:

- Amazon ECR
- Amazon EKS
- Kubernetes

EKS Access Entries allow the Jenkins IAM role to authenticate with the Kubernetes cluster.

A GitHub Personal Access Token stored in Jenkins Credentials provides access to the private GitHub repository.

---

## Jenkins CI/CD Pipeline

The CI/CD workflow is defined in the root `Jenkinsfile`.

The pipeline automates:

```text
GitHub Checkout
      ↓
Docker Build
      ↓
ECR Authentication
      ↓
Docker Image Tag
      ↓
ECR Push
      ↓
EKS Configuration
      ↓
Helm Deployment
      ↓
kubectl Rollout Verification
```

Each Jenkins build uses the Jenkins build number as a unique Docker image tag. This ensures each pipeline execution deploys a distinct application version rather than relying solely on the `latest` tag.

### CI/CD Validation

The complete pipeline was validated by making a visible change to the Flask application and pushing the updated source code to GitHub.

Jenkins successfully:

1. Checked out the updated source code from the private GitHub repository.
2. Built a new Docker image.
3. Tagged the image with the Jenkins build number.
4. Authenticated with Amazon ECR.
5. Pushed the new image to ECR.
6. Connected to the EKS cluster.
7. Updated the application using Helm.
8. Verified the Kubernetes rollout using kubectl.

The updated application was then accessed through the Application Load Balancer and returned:

**Hello, World! CI/CD Deployment Successful!**

---

## Key Validation Results

The completed project successfully demonstrated:

- Docker containerization
- Infrastructure provisioning with Terraform
- Amazon EKS deployment
- Kubernetes self-healing
- Helm-based application management
- Public Application Load Balancer routing
- CPU and memory-based HPA scaling
- EKS worker node autoscaling
- Siege load testing
- Jenkins access to a private GitHub repository
- Secure Jenkins AWS authentication using an EC2 IAM role
- Automated Docker builds
- Automated ECR image pushes
- Automated Helm deployments
- Kubernetes rollout verification
- Successful end-to-end CI/CD deployment

---

## Repository Structure

```text
devops-tech-challenge-2/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
├── helm/
│   └── tech-challenge-2/
├── images/
│   └── architecture-diagram.png
├── kubernetes/
│   ├── deployment.yaml
│   └── service.yaml
├── terraform/
├── Jenkinsfile
├── .gitignore
└── README.md
```

---

## Project Outcome

The project demonstrates a complete DevOps workflow in which AWS infrastructure is provisioned through Terraform, applications are containerized with Docker, workloads are orchestrated and automatically scaled through Kubernetes on Amazon EKS, and application updates are deployed through a Jenkins CI/CD pipeline.

The final environment successfully demonstrated:

**Code → Build → Container Registry → Kubernetes → Autoscaling → CI/CD → Production Deployment**