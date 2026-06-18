# Production VPC with Terraform

A complete,production-pattern AWS network provisioned entirely with 
Terraform. A reusable VPC module (multi-AZ public/private subnets, IGW, NAT),
two-tier security groups, an nginx web server, and a locked-down S3
bucket. Built as SkyHigh Academy Project 2 to demonstrate
infrastructure-as-code, module design, and least-privilege security."

---

## Proof of Production
<img width="946" height="130" alt="Screenshot 2026-06-17 at 11 35 40 PM" src="https://github.com/user-attachments/assets/147fc495-137c-4373-818d-b580cae1e444" />

---

## Architecture
![alt text](<Screenshot 2026-06-17 at 6.52.14 PM.png>)

A `10.0.0.0/16` VPC spans two Availability Zones (`us-east-1a`, `us-east-1b`). 
Each AZ holds one public subnet (`10.0.1.0/24`, `10.0.2.0/24`) and one private 
subnet (`10.0.3.0/24`, `10.0.4.0/24`). 
Public subnets route `0.0.0.0/0` to the Internet Gateway;
private subnets route `0.0.0.0/0` to a NAT Gateway, giving private instances
outbound-only internet access for patching while remaining unreachable from the
internet.

---

## Tech stack
- Terraform (AWS provider ~> 5.0)
- AWS VPC (multi-AZ, public + private subnets, IGW, NAT Gateway)
- Amazon EC2 (Amazon Linux 2023, nginx via user_data)
- Amazon S3 (versioned, public access blocked, encrypted)
- Terraform modules (reusable VPC module)

---

## Security decisions
- DB security group references the web SG, not a CIDR (identity-based least privilege)
- IMDSv2 enforced on EC2 (http_tokens = required) — SSRF mitigation
- S3: all four Block Public Access flags on; versioning + encryption enabled
- State kept out of Git; remote S3 backend with DynamoDB locking

---

## Deployment steps

> Prerequisite: an AWS account with credentials configured (`aws configure`), Terraform installed, and the remote-state backend already bootstrapped (the `skyhigh-terraform-state` S3 bucket and the DynamoDB lock table must exist before `init`).

```bash
# 1. Clone and enter the project
git clone https://github.com/freddie-c/skyhigh-portfolio-project-02.git
cd skyhigh-portfolio-project-02

# 2. Provide variable values
cp terraform.tfvars.example terraform.tfvars
#    Edit terraform.tfvars: set project_name, my_ip (your IP as x.x.x.x/32),
#    and a globally unique assets_bucket_name.

# 3. Initialize — downloads the AWS provider and connects the S3 backend
terraform init

# 4. Validate syntax and check the execution plan
terraform validate
terraform plan

# 5. Build the infrastructure
terraform apply

# 6. Verify the web server is serving
curl http://$(terraform output -raw web_server_public_ip)
#    Expected: Hello from Terraform!
#    Allow ~30-60s after apply for user_data to finish installing nginx.

# 7. Tear down when finished (see Cost Note)
terraform destroy
```

---


## Challenges and Solutions

Selected `user_data` script used `yum`, `sudo`, and assumed Amazon Linux 2 conventions — it failed on Amazon Linux 2023. Then switched to `dnf`, removed `sudo` (cloud-init already runs as root), and added `systemctl enable nginx` so the service survives a reboot.  

The database needed to reach the web tier without exposing it to the whole VPC. Made and update and used `referenced_security_group_id` on the DB ingress rule instead of a CIDR, so access is tied to security-group identity and survives instance IP churn. 


`terraform init` failed with "Unreadable module directory" — Terraform couldn't find the module at `./modules/vpc`. Figured out that the module folder was named `Module` (singular, capitalized) while the source path expected `modules` (plural, lowercase). Renamed the folder to match exactly — Terraform does a literal, case-sensitive path match. 

---


## Cost note

Most of this stack fits inside the AWS Free Tier, **with one important exception**:

- **NAT Gateway is not free.** Roughly around **~$0.045/hour (~$32/month)** plus **~$0.045/GB** of data processed in `us-east-1`. It bills as long as it exists, whether or not traffic flows. This is the single largest cost in the project. 
- **EC2 `t2.micro`** — Free Tier eligible (750 hours/month for the first 12 months).
- **S3** — Free Tier covers 5 GB; note that **versioning means you pay for every retained version**, so old versions accumulate cost over time.
- **Elastic IP** — free while attached to a running NAT Gateway; charged if left allocated but unattached.

A single NAT Gateway was chosen deliberately to **control lab cost** (vs. one-per-AZ for high availability). Because the NAT bills continuously, run `terraform destroy` whenever the lab isn't in use — that's the difference between a few cents and a monthly NAT charge.


---


## Future improvements

- **Web tier behind an Application Load Balancer in private subnets**, so the instance is never directly internet-facing — the production shape of this lab.
- **Replace SSH with SSM Session Manager** — removes port 22 entirely, no key pair to leak, every session logged in CloudTrail. The `my_ip` SSH rule would be dropped.
- **One NAT Gateway per AZ** for true high availability (the single NAT here is an Availability-Zone single point of failure).
- **RDS Postgres in the private subnets** using the existing DB security group, with `manage_master_user_password` to keep credentials out of Terraform state.
- **S3 lifecycle rule** to expire non-current object versions and cap the cost of versioning.
- **CI/CD via GitHub OIDC** — run `plan` on pull requests and gated `apply` on merge, with no long-lived AWS keys.

---