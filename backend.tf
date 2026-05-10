terraform {
  backend "s3" {
    bucket       = "bankapp-terraform-state2026"
    key          = "bankapp/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true   # Native S3 state locking
    workspace_key_prefix = "workspace"   # ← add this for dev/prod separation

    # Optional:
    # workspace_key_prefix = "env"
    # This creates:
    # env/dev/bankapp/terraform.tfstate
    # env/prod/bankapp/terraform.tfstate
  }
}