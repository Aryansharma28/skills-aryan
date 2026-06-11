---
name: private-instance
description: Set up a new private instance (isolated VPC + EKS + ClickHouse + S3) for a customer
---

# Private Instance Setup

> **Full guide:** `infrastructure/docs/private-instance-setup-guide.md`

Use this skill when a new customer needs a private instance (dedicated VPC + EKS cluster + ClickHouse + S3 isolation). Uses the `modules/private-instance` terraform module.

## Prerequisites

1. **Customer organization ID** — query the LangWatch database for the org ID
2. **Customer name** — lowercase, alphanumeric (e.g., `backbase`, `acme`)
3. **Next available VPC CIDR** — must not overlap:
   - `10.0.0.0/16` — main VPC (taken)
   - `10.20.0.0/16` — Backbase (taken)
   - `10.21.0.0/16` — next available

## Process

### Step 1: Create the instance file

Copy `infrastructure/backbase-instance.tf` as a template:

```bash
cp infrastructure/backbase-instance.tf infrastructure/<customer>-instance.tf
```

### Step 2: Customize

In the new file, change:

1. **Provider alias** — `"backbase"` → `"<customer>"`
2. **Module name** — `module "backbase"` → `module "<customer>"`
3. **`customer_name`** — `"backbase"` → `"<customer>"`
4. **`org_id`** — the customer's LangWatch org ID
5. **`vpc_cidr`** — next available CIDR (e.g., `"10.21.0.0/16"`)
6. **`subnet_cidrs`** — matching subnets (e.g., `["10.21.1.0/24", "10.21.2.0/24"]`)
7. **Provider references** — update `kubernetes.backbase` → `kubernetes.<customer>` and `module.backbase` → `module.<customer>`

### Step 3: Adjust sizing (optional)

The module defaults to 1/4 production. Override via `clickhouse_config`:

| Tier | Instance | CPU | Memory | Hot storage | Est. cost/mo |
|---|---|---|---|---|---|
| 1/4 prod (default) | m8g.large | 0.5/1 | 2Gi/3Gi | 75 GiB | ~$260 |
| 1/2 prod | m8g.xlarge | 1/2 | 4Gi/6Gi | 150 GiB | ~$410 |
| Full prod | m8g.4xlarge | 2/3 | 8Gi/12Gi | 300 GiB | ~$1,230 |

### Step 4: Apply

```bash
cd infrastructure/
terraform init    # Register the new module instance
terraform plan    # Expect ~35 resources
terraform apply   # Takes ~15 minutes (EKS creation is slow)
```

### Step 5: Verify

- [ ] EKS cluster status is ACTIVE
- [ ] Node group status is ACTIVE (nodes joined)
- [ ] VPC peering status is active
- [ ] ClickHouse pods are Running (2 data + 3 keeper)
- [ ] NLB endpoint reachable from main VPC on port 8123
- [ ] K8s secret created in main cluster with routing env vars
- [ ] Test trace routes to private ClickHouse

## Reference Files

| File | Purpose |
|---|---|
| `infrastructure/backbase-instance.tf` | Template to copy for new customers |
| `infrastructure/modules/private-instance/` | Reusable module (VPC + EKS + CH + S3) |
| `infrastructure/modules/clickhouse/` | ClickHouse deployment module (called internally) |
| `infrastructure/docs/private-instance-setup-guide.md` | Full setup guide |
| `infrastructure/docs/backbase-private-dataplane.md` | Backbase architecture docs |

## Teardown

Set `enable_clickhouse = false` in the customer's instance file and run `terraform apply`. To fully remove, delete the instance file. S3 buckets have `prevent_destroy` — remove manually if needed.
