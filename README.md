The kpalmer412/genomics-data-hub repository is an open-source tool for centralizing, structuring, and managing biological datasets, designed for researchers and bioinformaticians needing customizable data pipelines without high costs. It serves as a lightweight alternative to commercial enterprise solutions that you may need have the resources to do so. ### 🔒 Infrastructure Update: Secure Remote State Backend & Locking

**What Changed:**
- Configured a remote S3 state backend (`ken-genomics-tfstate-2026`) to keep the infrastructure tracking file off local hard drives.
- Enabled **S3 Bucket Server-Side Encryption (AES256)** and **Bucket Versioning** for state recovery and rollbacks.
- Integrated runtime **State Concurrency Locking** via DynamoDB to prevent team members from stepping on each other's simultaneous deployments.

**Action Required for Team Members:**
1. Ensure your local environment has active AWS CLI permissions targeting the HCLS account.
2. Pull this branch and run:
   ```zsh
   terraform init
   ```

