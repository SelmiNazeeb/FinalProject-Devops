# Three-Tier Taskflow Application in AWS EKS Cluster

- **Frontend**: React application
- **Backend**: Node.js/Express API
- **Database**: AWS RDS PostgreSQL

## Architecture

```
Frontend (React) → Backend (Node.js) → Database (AWS RDS PostgreSQL)
```

## Project Structure

FinalProject-Devops/
├── frontend/                   # React frontend application
├── backend/                    # Node.js backend API
├── k8s/                        # Kubernetes manifests
├── terraform_infra/            # terraform infrastructure
└── cft.yaml                    # cloud formation infrastructure
|__ buildspec.yaml              # cloud formation deploy
|__ buildspec_Sonarqube.yaml    # tsonarqube integration      
|__ buildspec_terraform.yaml    # terraform infrastructure build 
|__ database/                   # posgresql database


## steps

### 1. create infrastructure (cloud formation and terraform in 2 region)
### 2. Build and Push Docker Images to ecr registry
### 3. Applying manifest files
### 4. Deploy to AWS EKS
### 5. buy domain from route 53
### 6. Route 53 for failover routing
### 7. cloud watch monitoring
