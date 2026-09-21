# Tech Challenge 2 V2 — GitOps, CI/CD & Observability

## Project Overview

Tech Challenge 2 V2 is an evolution of my original AWS EKS DevOps project.

V1 used Jenkins to build, push, and deploy a containerized Flask application to Amazon EKS. V2 modernizes the architecture by introducing GitHub Actions for Continuous Integration, Argo CD for Continuous Delivery, GitOps for Kubernetes deployment management, and Prometheus/Grafana for observability.

The project demonstrates a production-style workflow combining Infrastructure as Code, containers, Kubernetes, CI/CD, GitOps, autoscaling, monitoring, and AWS cloud infrastructure.

---

## Architecture

### V1

```text
GitHub
   ↓
Jenkins
   ↓
Docker
   ↓
Amazon ECR
   ↓
Helm / kubectl
   ↓
Amazon EKS
   ↓
Application Load Balancer
   ↓
Flask Application
```

### V2

```text
Developer
   ↓
GitHub
   ↓
GitHub Actions
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
Git Desired State
   ↓
Argo CD
   ↓
Helm / Kubernetes
   ↓
Amazon EKS
   ↓
Application Load Balancer
   ↓
Flask Application
```

### Observability

```text
Amazon EKS / Kubernetes
          ↓
      Prometheus
          ↓
        Grafana
```

Terraform provisions and manages the underlying AWS infrastructure.

---

## V1 to V2 Evolution

| Area | V1 | V2 |
|---|---|---|
| CI | Jenkins | GitHub Actions |
| CD | Jenkins + Helm | Argo CD |
| Deployment Model | Pipeline-driven | GitOps |
| Image Versioning | Jenkins Build Number | Git Commit SHA |
| AWS Authentication | Jenkins EC2 IAM Role | GitHub OIDC + IAM |
| Monitoring | Kubernetes Metrics | Prometheus + Grafana |
| Infrastructure | Terraform | Terraform |

The main architectural change in V2 is separating CI from CD. GitHub Actions builds and publishes application images, while Argo CD continuously reconciles Kubernetes with the desired state stored in Git.

---

## Technology Stack

- AWS — EKS, ECR, EC2, VPC, IAM, ALB, EBS
- Terraform — Infrastructure as Code
- Docker — Application containerization
- Kubernetes — Container orchestration
- Helm — Kubernetes application packaging
- GitHub Actions — Continuous Integration
- Argo CD — Continuous Delivery
- GitOps — Desired-state deployment management
- Prometheus — Metrics collection
- Grafana — Monitoring dashboards
- Metrics Server — HPA metrics
- Siege — Load testing
- Python / Flask — Application

---

## Infrastructure as Code

Terraform provisions the AWS infrastructure, including:

- Custom VPC
- Public and private subnets
- Internet and NAT gateways
- Amazon ECR repository
- Amazon EKS cluster
- Managed EKS node group
- IAM roles and policies
- GitHub Actions OIDC/IAM integration
- AWS Load Balancer Controller IAM
- Cluster Autoscaler IAM
- EBS CSI Driver IAM

EKS worker nodes run in private subnets while the Application Load Balancer provides public access to the Flask application.

---

## Kubernetes & Helm

The Flask application is deployed to Amazon EKS using Kubernetes and Helm.

The deployment includes:

- Kubernetes Deployment
- ClusterIP Service
- ALB Ingress
- Readiness and liveness probes
- CPU and memory requests/limits
- Horizontal Pod Autoscaler
- Topology spread constraints

Application traffic follows:

```text
Internet
   ↓
AWS Application Load Balancer
   ↓
Kubernetes Ingress
   ↓
ClusterIP Service
   ↓
Flask Pods
```

---

## GitHub Actions CI

GitHub Actions automatically triggers when application code changes.

The CI workflow:

1. Checks out the repository.
2. Authenticates to AWS using OIDC.
3. Builds the Flask Docker image.
4. Tags the image using the Git commit SHA.
5. Pushes the image to Amazon ECR.
6. Updates the Helm image tag in Git.
7. Commits the new desired state.

Using Git commit SHAs provides immutable image versioning and traceability between application code, ECR images, Git, and EKS.

---

## GitOps & Argo CD

Argo CD manages Continuous Delivery using GitOps.

Git is treated as the source of truth for the Kubernetes application's desired state.

```text
Git Desired State
       ↓
    Argo CD
       ↓
     Helm
       ↓
 Kubernetes / EKS
```

Argo CD was configured with:

- Automatic synchronization
- Self-healing
- Helm-based deployments
- Continuous Git reconciliation

Both Git-based application updates and deliberate Kubernetes drift were tested to validate synchronization and self-healing.

---

## Monitoring & Persistent Storage

Prometheus and Grafana provide observability for the EKS environment.

Prometheus collects Kubernetes, node, and workload metrics. Grafana provides dashboards for visualizing cluster and application behavior.

Persistent storage for monitoring workloads is provided through the AWS EBS CSI Driver and Kubernetes PersistentVolumes/PersistentVolumeClaims.

---

## Autoscaling

The environment uses two levels of autoscaling.

### Horizontal Pod Autoscaler

The Flask application can scale between:

- Minimum replicas: `1`
- Maximum replicas: `12`
- CPU target: `50%`
- Memory target: `50%`

### Cluster Autoscaler

Cluster Autoscaler dynamically adjusts EKS worker capacity when pods cannot be scheduled.

The node group supports up to `5` worker nodes using `t3.small` instances.

```text
Application Load Increases
        ↓
HPA Creates More Pods
        ↓
Scheduler Places Pods
        ↓
Additional Capacity Required
        ↓
Cluster Autoscaler Adds Nodes
```

---

## Load Testing

Siege was used to generate sustained traffic through the public Application Load Balancer.

Final load test:

- 50 concurrent users
- 5-minute duration
- 45,878 successful transactions
- 0 failed transactions
- 100% availability
- 152.63 transactions/second

During testing:

- HPA scaled the Flask application from `1` to `12` pods.
- Cluster Autoscaler increased EKS worker capacity.
- Kubernetes distributed application replicas across worker nodes.
- The environment automatically scaled down after demand decreased.

---

## End-to-End CI/CD Validation

The completed V2 pipeline was validated using a visible Flask application change.

```text
Code Push
   ↓
GitHub Actions
   ↓
Docker Build
   ↓
SHA-Tagged Image
   ↓
Amazon ECR
   ↓
Git Desired State Updated
   ↓
Argo CD Auto-Sync
   ↓
Amazon EKS
   ↓
Application Load Balancer
   ↓
Updated Flask Application
```

The final deployment successfully ran the SHA-versioned image in EKS, reached Healthy/Synced status in Argo CD, and served the updated Flask application through the public ALB.

---

## Troubleshooting Highlights

### GitHub Actions OIDC Authentication

GitHub Actions initially failed to assume its AWS IAM role because the repository identity in the OIDC token did not match the IAM trust policy.

The actual OIDC claims were inspected and the IAM trust relationship was updated to match the repository identity.

### Cluster Autoscaler IRSA

Cluster Autoscaler initially failed AWS authentication because its Kubernetes ServiceAccount did not match the identity configured in the IAM trust relationship.

The ServiceAccount and IRSA configuration were aligned to restore AWS access.

### Kubernetes Scheduling Capacity

During a GitOps rolling deployment, a new Flask pod remained Pending.

Investigation showed:

- Two nodes had reached their pod capacity.
- Two nodes were restricted by topology spread constraints.
- Cluster Autoscaler had reached the configured four-node maximum.

The node-group maximum was increased to five, allowing Cluster Autoscaler to add capacity. Kubernetes successfully scheduled the new SHA-versioned Flask pods and completed the rolling deployment.

### Prometheus Persistent Storage

Prometheus initially remained Pending because persistent EBS storage was unavailable.

The AWS EBS CSI Driver, IAM role, and persistent storage configuration were added, allowing Kubernetes to dynamically provision EBS-backed storage.

---

## Key Results

The completed project demonstrates:

- Terraform-managed AWS infrastructure
- Containerized Flask application
- Production-style Amazon EKS deployment
- GitHub Actions CI
- Secure AWS authentication using OIDC
- Immutable SHA-based Docker image versioning
- GitOps-based Continuous Delivery
- Argo CD Auto-Sync and Self-Healing
- Kubernetes HPA
- EKS Cluster Autoscaler
- Prometheus monitoring
- Grafana dashboards
- EBS-backed persistent storage
- ALB-based public application access
- Successful load testing with 100% availability
- End-to-end automated CI/CD deployment

---

## Repository Structure

```text
devops-tech-challenge-2-v2/
├── .github/
│   └── workflows/
├── app/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── helm/
│   └── tech-challenge-2/
├── images/
├── kubernetes/
├── terraform/
├── Jenkinsfile
├── .gitignore
└── README.md
```

The `Jenkinsfile` is retained as a reference to the original V1 implementation and demonstrates the project's evolution from Jenkins-based CI/CD to GitHub Actions and Argo CD.

---

## Project Outcome

Tech Challenge 2 V2 demonstrates the evolution of a traditional CI/CD pipeline into a GitOps-based cloud deployment architecture.

The final environment integrates Terraform, AWS, Docker, Kubernetes, Helm, GitHub Actions, Argo CD, Prometheus, Grafana, autoscaling, persistent storage, and load testing into a single end-to-end DevOps platform.

The project provided hands-on experience designing, automating, monitoring, scaling, and troubleshooting a Kubernetes-based application running on AWS.