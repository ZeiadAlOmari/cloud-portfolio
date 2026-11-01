#!/usr/bin/env bash
# Project 8 - direct-API leftover sweep (read-only). Usage: bash sweep.sh
set -u
export AWS_PAGER=""
T="--cli-connect-timeout 10 --cli-read-timeout 20"

run() {
  local label="$1"; shift
  echo "== $label"
  timeout 45 aws "$@" $T 2>&1 || echo "   (error or timeout, rc=$?)"
}

run "S3 BUCKETS (global)" s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text
run "CLOUDFRONT (global)" cloudfront list-distributions --query 'DistributionList.Items[].[Id,Status,Enabled]' --output text

for R in us-east-1 us-west-2; do
  echo "######## $R"
  run "EC2 INSTANCES"      ec2 describe-instances --region "$R" --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
  run "EBS VOLUMES"        ec2 describe-volumes --region "$R" --query 'Volumes[].[VolumeId,Size,State]' --output text
  run "EBS SNAPSHOTS"      ec2 describe-snapshots --region "$R" --owner-ids self --query 'Snapshots[].[SnapshotId,VolumeSize]' --output text
  run "ELASTIC IPS"        ec2 describe-addresses --region "$R" --query 'Addresses[].PublicIp' --output text
  run "NON-DEFAULT VPCS"   ec2 describe-vpcs --region "$R" --filters Name=is-default,Values=false --query 'Vpcs[].VpcId' --output text
  run "KEY PAIRS"          ec2 describe-key-pairs --region "$R" --query 'KeyPairs[].KeyName' --output text
  run "RDS INSTANCES"      rds describe-db-instances --region "$R" --query 'DBInstances[].DBInstanceIdentifier' --output text
  run "RDS SNAPSHOTS"      rds describe-db-snapshots --region "$R" --query 'DBSnapshots[].[DBSnapshotIdentifier,SnapshotType,AllocatedStorage]' --output text
  run "RDS PARAM GROUPS (non-default)" rds describe-db-parameter-groups --region "$R" --query 'DBParameterGroups[?!starts_with(DBParameterGroupName,`default.`)].DBParameterGroupName' --output text
  run "RDS SUBNET GROUPS"  rds describe-db-subnet-groups --region "$R" --query 'DBSubnetGroups[].DBSubnetGroupName' --output text
  run "REST APIS (v1)"     apigateway get-rest-apis --region "$R" --query 'items[].[name,id,createdDate]' --output text
  run "HTTP APIS (v2)"     apigatewayv2 get-apis --region "$R" --query 'Items[].Name' --output text
  run "LAMBDA"             lambda list-functions --region "$R" --query 'Functions[].FunctionName' --output text
  run "CFN STACKS"         cloudformation list-stacks --region "$R" --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE DELETE_FAILED --query 'StackSummaries[].StackName' --output text
  run "LOG GROUPS"         logs describe-log-groups --region "$R" --query 'logGroups[].[logGroupName,storedBytes]' --output text
done
echo "== SWEEP DONE"
