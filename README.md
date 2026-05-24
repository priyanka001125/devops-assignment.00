# DevOps Engineer Assignment - NimbusKart Cost Optimization

## Overview

NimbusKart, an e-commerce startup, experienced unexpected cloud cost growth from $400 to $2,100 per month. The engineering team suspects wasteful resources such as unattached EBS volumes, stopped EC2 instances left running for weeks, unused Elastic IPs, and untagged development resources.

This project implements a cost hygiene automation solution with three components:
- **Part A:** Infrastructure as Code using Terraform to provision AWS resources (VPC, EC2, S3, intentionally orphaned EBS volume)
- **Part B:** "Cost Janitor" Python script that detects orphaned resources and a GitHub Actions workflow for CI/CD integration
- **Part C:** Design document for production hardening, multi-cloud support, security, and observability

The entire assignment runs locally using **Moto** (AWS mock library) - no real AWS account or cloud costs required.

---

## How to Run Locally

### Prerequisites

Before running, ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.10+ | Running the Cost Janitor script |
| Terraform | 1.5+ | Infrastructure provisioning |
| pip | Latest | Installing Python dependencies |
| Git | Latest | Cloning the repository |

### Step-by-Step Instructions

#### 1. Clone the Repository

git clone https://github.com/priyanka001125/devops-assignment.git
cd devops-assignment

2. Install Python Dependencies
pip install boto3 moto terraform-local

3. Start Moto Server (AWS Mock)
Open a new terminal window and run:

moto_server -p 4566
Keep this terminal window open - the server must stay running in the background.

You should see output like:

WARNING: This is a development server.
* Running on http://127.0.0.1:4566

4. Initialize and Apply Terraform
In your original terminal window, run:

cd terraform
tflocal init
tflocal plan
tflocal apply -auto-approve
Expected output:

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:
s3_bucket_name = "nimbuskart-logs-20260123114530"
subnet_ids = [
  "subnet-xxxxx",
  "subnet-xxxxx",
]
vpc_id = "vpc-xxxxx"

5. Run the Cost Janitor Script

cd ../scripts
python cost_janitor.py --dry-run

Expected output:
Report saved to report.json and summary.md
DRY RUN: Found X orphaned resources

6. View the Report
type report.json
The report contains:

scan_timestamp: When the scan was performed

account_id: AWS account ID (mock: 000000000000)

region: AWS region (us-east-1)

summary.total_orphans: Number of wasteful resources found

summary.estimated_monthly_waste_usd: Estimated monthly cost of waste

findings: Array of individual resource details

7. Clean Up Resources
When done testing, destroy the infrastructure:
cd ../terraform
tflocal destroy -auto-approve

Then stop the Moto server by pressing Ctrl+C in its terminal window.


Architecture

┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Actions (CI/CD)                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ 1. Start Moto Server (AWS mock)                                       │  │
│  │ 2. Apply Terraform (VPC, EC2, S3, EBS)                                │  │
│  │ 3. Run Cost Janitor Script in --dry-run mode                          │  │
│  │ 4. Generate report.json and summary.md                                │  │
│  │ 5. Upload artifacts to workflow                                       │  │
│  │ 6. Post comment on Pull Request if orphans found                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Local Development                              │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐      │
│  │    Terraform     │───▶│   Moto Server    │───▶│   Cost Janitor   │      │
│  │    (IaC)         │    │   (AWS Mock)     │    │    (Python)      │      │
│  │                  │    │   Port: 4566     │    │                  │      │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘




Resource Diagram (What Terraform Creates)

                    ┌─────────────────────────────────────┐
                    │              VPC                     │
                    │         CIDR: 10.20.0.0/16          │
                    │                                     │
                    │  ┌─────────────┐  ┌─────────────┐   │
                    │  │  Subnet 1   │  │  Subnet 2   │   │
                    │  │ us-east-1a  │  │ us-east-1b  │   │
                    │  └──────┬──────┘  └──────┬──────┘   │
                    │         │                │          │
                    │         ▼                ▼          │
                    │  ┌─────────────┐  ┌─────────────┐   │
                    │  │  EC2 Web    │  │  EC2 Web    │   │
                    │  │  Instance 1 │  │  Instance 2 │   │
                    │  └─────────────┘  └─────────────┘   │
                    │                                     │
                    │  ┌─────────────────────────────┐    │
                    │  │      Security Group         │    │
                    │  │  Port 80: 0.0.0.0/0 (HTTP)  │    │
                    │  │  Port 443: 0.0.0.0/0 (HTTPS)│    │
                    │  │  Port 22: 0.0.0.0/0 (SSH) ⚠️ │    │
                    │  └─────────────────────────────┘    │
                    └─────────────────────────────────────┘

                    ┌─────────────────────────────┐
                    │         S3 Bucket            │
                    │    (Application Logs)        │
                    │  - Versioning: Enabled       │
                    │  - Lifecycle: 30 days        │
                    └─────────────────────────────┘

                    ┌─────────────────────────────┐
                    │      EBS Volume (Orphan)     │
                    │    Size: 20 GB, gp3          │
                    │    NOT attached to any EC2   │
                    │    (Intentional waste)       │
                    └─────────────────────────────┘


Decisions & Deviations

Decision	                    Reason

Port 22 open to 0.0.0.0/0	    Followed spec but flagged as insecure. Production should restrict to VPN/bastion IPs only.
Moto instead of LocalStack	    LocalStack had WSL2 compatibility issues on Windows. Moto is explicitly allowed in the assignment (Page 3, Section 4.1).
Static pricing hardcoded	    Using static prices from AWS public pricing. Production would integrate AWS Price List API.
No real AWS account used	    Entire assignment runs locally with mocked APIs to avoid any real cloud costs.
EBS orphan volume created	    Intentionally unattached volume included to test cleanup automation in Part B.
Protected tag guardrail	            Resources with Protected=true tag are never deleted, even in --delete mode.

Trade-offs (What I would do with one more week)

Priority	Improvement	           Why
1	        Dynamic pricing	           Integrate AWS Price List API instead of hardcoded static prices.
2	        Multi-region scanning	   Currently scans only us-east-1. Production needs all regions.
3	        Database backend	   Store findings in DynamoDB/RDS for historical trending analysis.
4	        Scheduled execution	   Add CloudWatch Events cron job for daily automated scans.
5	        Web dashboard	           Build React dashboard showing waste trends and top offenders.
6	        Unit tests	           Add pytest with moto mocking for comprehensive test coverage.
7	        Terraform state locking	   Use DynamoDB backend for state locking in production.


AI Usage Disclosure
Tools Used

Tool	  Purpose
ChatGPT	  Initial script structure, error handling patterns, debugging assistance
GitHub    Copilot	Terraform module boilerplate, boto3 client setup, repetitive code
Claude	  Moto server connection debugging, PATH configuration issues

