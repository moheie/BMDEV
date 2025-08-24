# Terraform backend configuration for state management
# Uncomment and modify the backend configuration below for production use

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "solar-system/terraform.tfstate"
#     region         = "us-west-2"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# For local development, Terraform will use local state
# For production, consider using remote state with S3 backend
