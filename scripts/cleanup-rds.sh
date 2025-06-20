#!/bin/bash

# CloudOps Demo - RDS Cleanup Script
# This script removes the RDS PostgreSQL database and related resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION=${AWS_REGION:-"us-west-2"}
STACK_NAME="cloudops-demo-rds"

echo -e "${BLUE}🗑️  Cleaning up AWS RDS resources for CloudOps Demo${NC}"
echo "=================================================="

# Confirm deletion
echo -e "${YELLOW}⚠️  This will delete the following resources:${NC}"
echo "  - RDS PostgreSQL instance"
echo "  - Security groups"
echo "  - DB subnet group"
echo "  - All associated data (with final snapshot)"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
fi

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Stack $STACK_NAME does not exist${NC}"
    exit 0
fi

# Delete CloudFormation stack
echo -e "${YELLOW}🗑️  Deleting CloudFormation stack: $STACK_NAME${NC}"
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

echo -e "${YELLOW}⏳ Waiting for stack deletion to complete...${NC}"
echo -e "${BLUE}💡 This may take 10-15 minutes as RDS creates a final snapshot${NC}"

aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ RDS resources cleaned up successfully${NC}"
else
    echo -e "${RED}❌ Failed to delete RDS stack${NC}"
    echo -e "${YELLOW}💡 Check AWS Console for manual cleanup if needed${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Cleanup completed successfully!${NC}" 