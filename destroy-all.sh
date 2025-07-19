#!/bin/bash

echo "Running terraform destroy..."

terraform init
terraform destroy -auto-approve