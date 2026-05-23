#!/usr/bin/env python3
"""
Cost Janitor - Detects orphaned AWS resources
"""

import json
import argparse
import boto3
from datetime import datetime, timezone
from constants import EBS_GP3_PRICE_PER_GB_MONTH, EC2_T3_MICRO_PRICE_PER_HOUR, ELASTIC_IP_PRICE_PER_HOUR

REQUIRED_TAGS = {"Project", "Environment", "Owner"}

def scan_ebs_volumes(ec2, dry_run):
    findings = []
    waste = 0
    try:
        volumes = ec2.describe_volumes()['Volumes']
        for vol in volumes:
            if vol['State'] == 'available':
                cost = vol['Size'] * EBS_GP3_PRICE_PER_GB_MONTH
                waste += cost
                findings.append({
                    "resource_id": vol['VolumeId'],
                    "resource_type": "ebs_volume",
                    "reason": "unattached",
                    "age_days": 0,
                    "estimated_monthly_waste_usd": round(cost, 2)
                })
                if not dry_run:
                    tags = {t['Key']: t['Value'] for t in vol.get('Tags', [])}
                    if tags.get('Protected') != 'true':
                        ec2.delete_volume(VolumeId=vol['VolumeId'])
    except Exception as e:
        print(f"Error scanning volumes: {e}")
    return findings, waste

def scan_stopped_instances(ec2, dry_run, max_days=14):
    findings = []
    waste = 0
    try:
        reservations = ec2.describe_instances()['Reservations']
        for res in reservations:
            for inst in res['Instances']:
                if inst['State']['Name'] == 'stopped':
                    launch_time = inst['LaunchTime']
                    age = (datetime.now(timezone.utc) - launch_time).days
                    if age > max_days:
                        cost = EC2_T3_MICRO_PRICE_PER_HOUR * 24 * 30
                        waste += cost
                        findings.append({
                            "resource_id": inst['InstanceId'],
                            "resource_type": "ec2_instance",
                            "reason": f"stopped for {age} days",
                            "age_days": age,
                            "estimated_monthly_waste_usd": round(cost, 2)
                        })
                        if not dry_run:
                            tags = {t['Key']: t['Value'] for t in inst.get('Tags', [])}
                            if tags.get('Protected') != 'true':
                                ec2.terminate_instances(InstanceIds=[inst['InstanceId']])
    except Exception as e:
        print(f"Error scanning instances: {e}")
    return findings, waste

def scan_elastic_ips(ec2, dry_run):
    findings = []
    waste = 0
    try:
        addresses = ec2.describe_addresses()['Addresses']
        for addr in addresses:
            if 'InstanceId' not in addr and 'AssociationId' not in addr:
                cost = ELASTIC_IP_PRICE_PER_HOUR * 24 * 30
                waste += cost
                findings.append({
                    "resource_id": addr.get('AllocationId', addr.get('PublicIp')),
                    "resource_type": "elastic_ip",
                    "reason": "unassociated",
                    "age_days": 0,
                    "estimated_monthly_waste_usd": round(cost, 2)
                })
                if not dry_run:
                    ec2.release_address(AllocationId=addr['AllocationId'])
    except Exception as e:
        print(f"Error scanning EIPs: {e}")
    return findings, waste

def scan_missing_tags(ec2, dry_run):
    findings = []
    waste = 0
    try:
        volumes = ec2.describe_volumes()['Volumes']
        for vol in volumes:
            tags = {t['Key']: t['Value'] for t in vol.get('Tags', [])}
            missing = REQUIRED_TAGS - set(tags.keys())
            if missing:
                findings.append({
                    "resource_id": vol['VolumeId'],
                    "resource_type": "ebs_volume",
                    "reason": f"missing tags: {missing}",
                    "age_days": 0,
                    "estimated_monthly_waste_usd": 0
                })
    except Exception as e:
        print(f"Error scanning tags: {e}")
    return findings, waste

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true', default=True, help='Dry run mode (default)')
    parser.add_argument('--delete', action='store_true', help='Delete mode')
    parser.add_argument('--max-stopped-days', type=int, default=14, help='Max days for stopped instances')
    args = parser.parse_args()
    
    dry_run = not args.delete
    
    # Connect to Moto/LocalStack
    session = boto3.Session(
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )
    ec2 = session.client('ec2', endpoint_url='http://localhost:4566')
    
    all_findings = []
    total_waste = 0
    
    # Run all scans
    findings, waste = scan_ebs_volumes(ec2, dry_run)
    all_findings.extend(findings)
    total_waste += waste
    
    findings, waste = scan_stopped_instances(ec2, dry_run, args.max_stopped_days)
    all_findings.extend(findings)
    total_waste += waste
    
    findings, waste = scan_elastic_ips(ec2, dry_run)
    all_findings.extend(findings)
    total_waste += waste
    
    findings, waste = scan_missing_tags(ec2, dry_run)
    all_findings.extend(findings)
    total_waste += waste
    
    # Create report
    report = {
        "scan_timestamp": datetime.now(timezone.utc).isoformat(),
        "account_id": "000000000000",
        "region": "us-east-1",
        "summary": {
            "total_orphans": len(all_findings),
            "estimated_monthly_waste_usd": round(total_waste, 2)
        },
        "findings": all_findings
    }
    
    # Save JSON report
    with open('report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    # Save Markdown summary
    with open('summary.md', 'w') as f:
        f.write(f"# Cost Janitor Report\n\n")
        f.write(f"**Scan Time:** {report['scan_timestamp']}\n\n")
        f.write(f"**Total Orphans Found:** {report['summary']['total_orphans']}\n\n")
        f.write(f"**Estimated Monthly Waste:** ${report['summary']['estimated_monthly_waste_usd']}\n\n")
        f.write("## Findings\n\n")
        for fnd in all_findings[:20]:
            f.write(f"- **{fnd['resource_id']}** ({fnd['resource_type']}): {fnd['reason']} - ${fnd['estimated_monthly_waste_usd']}/month\n")
    
    print(f"Report saved to report.json and summary.md")
    
    if dry_run:
        print(f"DRY RUN: Found {len(all_findings)} orphaned resources")
        if len(all_findings) > 0:
            print("Exiting with non-zero status (CI will fail)")
            exit(1)
    else:
        print(f"DELETE MODE: Cleaned up {len(all_findings)} resources")
        exit(0)

if __name__ == "__main__":
    main()