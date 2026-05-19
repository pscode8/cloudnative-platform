# 1. Dev variables default region
sed -i 's/default     = "us-east-1"/default     = "us-east-2"/' \
  infra/terraform/environments/dev/variables.tf

# 2. Global variables default region
sed -i 's/default     = "us-east-1"/default     = "us-east-2"/' \
  infra/terraform/global/variables.tf

# 3. Comment in vpc/main.tf (cosmetic but clean)
sed -i 's/us-east-1a goes down, us-east-1b and 1c/us-east-2a goes down, us-east-2b and 2c/' \
  infra/terraform/modules/vpc/main.tf
