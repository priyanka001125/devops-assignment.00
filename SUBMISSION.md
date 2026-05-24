 Submission - DevOps Engineer Assignment



Candidate name: Priyanka



Email:priya593155@gmail.com



Date submitted: 2026-05-24



Hours spent (approximate): 8 hours



Deliverables checklist



[x] Part A: Terraform code under /terraform applies cleanly on LocalStack

[x] Part A: 'terraform validate' and 'terraform fmt -check' both pass

[x] Part B: Janitor script runs in --dry-run mode and produces report.json

[x] Part B: GitHub Actions workflow runs green on a fresh PR

[x] Part B: --delete mode respects Protected=true tag

[x] Part C: DESIGN.md is present and within 2 pages

[x] Walkthrough video link below is accessible (unlisted is fine)



Walkthrough video



Link: [YouTube/Your video link here]



Length: 5 minutes



Sample report



Path to a sample report.json produced by your script:



`/scripts/report.json`



 Known limitations


Moto used instead of LocalStack (WSL2 compatibility issue on Windows)

Static pricing instead of AWS Price List API

Single region (us-east-1) only

No multi-account support

Tags check only on EBS volumes (not all resources)



AI usage disclosure



Tools used:
ChatGPT: Initial script structure, error handling

Copilot: Terraform boilerplate

Claude: Moto debugging



AI mistake: Suggested tflocal without confirming PATH configuration



Wrote manually: Detection logic, safety guardrails, README decisions

