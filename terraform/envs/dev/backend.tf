# Local state for now. The cluster is destroyed after each session.
# To move to S3 later: create the bucket, add the block below, run `terraform init -migrate-state`.
#
# terraform {
#   backend "s3" {
#     bucket       = "<your-state-bucket>"
#     key          = "practice-k8s/dev/terraform.tfstate"
#     region       = "eu-central-1"
#     use_lockfile = true
#   }
# }
