\# Design Note - Cost Janitor Production Hardening



\## Multi-cloud Reality (GCP + Azure)



To add GCP and Azure without rewriting core:



\### Module Boundaries

┌─────────────────────────────────────────────────────────────┐

│ Cost Janitor Core │

│ - Orchestrator (runs all scanners) │

│ - Report generator (JSON schema) │

│ - Alerting \& notification │

└─────────────────────────────────────────────────────────────┘

│

┌─────────────────────┼─────────────────────┐

▼ ▼ ▼

┌───────────────┐ ┌───────────────┐ ┌───────────────┐

│ AWS Scanner │ │ GCP Scanner │ │ Azure Scanner │

│ - EBS volumes │ │ - Persistent │ │ - Unmanaged │

│ - EC2 stopped │ │ disks │ │ disks │

│ - EIPs │ │ - Stopped VMs │ │ - Stopped VMs │

│ - Tags │ │ - Static IPs │ │ - Public IPs │

└───────────────┘ └───────────────┘ └───────────────┘



text



Each cloud scanner implements a common `Scanner` interface with `scan()` and `cleanup()` methods.



\## IAM Permissions



\### Read-only mode (--dry-run)

```json

{

&#x20; "Version": "2012-10-17",

&#x20; "Statement": \[

&#x20;   {

&#x20;     "Effect": "Allow",

&#x20;     "Action": \[

&#x20;       "ec2:DescribeVolumes",

&#x20;       "ec2:DescribeInstances",

&#x20;       "ec2:DescribeAddresses",

&#x20;       "ec2:DescribeTags"

&#x20;     ],

&#x20;     "Resource": "\*"

&#x20;   }

&#x20; ]

}

Delete mode (--delete) - additional permissions

json

{

&#x20; "Version": "2012-10-17",

&#x20; "Statement": \[

&#x20;   {

&#x20;     "Effect": "Allow",

&#x20;     "Action": \[

&#x20;       "ec2:DeleteVolume",

&#x20;       "ec2:TerminateInstances",

&#x20;       "ec2:ReleaseAddress"

&#x20;     ],

&#x20;     "Resource": "\*",

&#x20;     "Condition": {

&#x20;       "StringNotEquals": {

&#x20;         "aws:ResourceTag/Protected": "true"

&#x20;       }

&#x20;     }

&#x20;   }

&#x20; ]

}

Safety Net - Two Failure Modes

Failure 1: Deleting attached volumes

Risk: Script misidentifies attached volume as orphan

Guardrail:



Verify State == 'available' AND Attachments array is empty



Double-check with DescribeVolumes status polling



Require 48-hour grace period before deletion



Failure 2: Terminating running production instances

Risk: Instance state check fails or misreads stopped state

Guardrail:



Never delete instances with DeleteOnTermination=true root volumes



Require Protected=true tag for all production resources



Implement canary deployment: delete 1% of resources first, monitor metrics



Observability Metrics

Metric	Source	Threshold	Alert

orphan\_count\_total	Janitor script	> 5 for 3 consecutive days	P2 ticket

estimated\_waste\_usd	Janitor script	> $100/month	Slack notification

janitor\_failures\_total	Script exit code	> 0	P1 on-call

deletion\_safety\_violations	Script logs	Any	P0 security

dry\_run\_success\_rate	CI pipeline	< 95%	P2 incident

What I did not build

Real AWS account integration - Assignment required local-only to avoid costs



Database backend - Reports are file-based; production would need DynamoDB/BigQuery



Scheduled execution - Currently PR-triggered; would add CloudWatch Events cron



Cost anomaly detection - ML-based detection of unusual spending patterns



Multi-region scanning - Currently us-east-1 only



Web UI dashboard - CLI-only for V1



Terraform state locking - Not needed for local demo



End-to-end encryption - Mock environment doesn't require TLS



Rationale: Focused on core detection + safety + CI integration. Value is in the automation pattern, not feature completeness.



text



\---



