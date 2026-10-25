# Cost estimate

Two different things cost money here: **building** the AMI (this pipeline)
and **running** instances from it (your workload). Prices are US East
(N. Virginia) on-demand, illustrative as of 2026 - check the
[AWS Pricing Calculator](https://calculator.aws) for current numbers in
your region.

## Build-time cost (per Packer build / per CI run)

| Item | Typical value | Approx. cost |
|---|---|---|
| Build instance (`t3.micro`, on-demand) | ~10-15 minutes wall clock | $0.0104/hr x ~0.25 hr ≈ **$0.003** |
| Root EBS volume (10 GiB gp3, transient) | provisioned for the build duration only | ≈ **$0.001** |
| EBS snapshot backing the finished AMI | 10 GiB gp3-equivalent, persists until you deregister it | **$0.08/GiB-month** ≈ **$0.80/month** per AMI version kept |
| Data transfer | negligible (package downloads from AWS-local repos, SSM/CloudWatch over VPC endpoints or NAT) | ~**$0.00-0.05** |
| GitHub Actions minutes | ~10-20 min/run on a public/private repo runner | Free tier covers this on most plans; otherwise standard per-minute billing |

**Net: a single build costs well under $0.05 in AWS spend.** The ongoing
cost is **storage for AMI snapshots you keep** - prune old versions
(`aws ec2 deregister-image` + delete the backing snapshot) or you'll
accumulate ~$0.80/month per retained version indefinitely. The weekly
scheduled rebuild in the pipeline will create a new version every week if
left on, so set a retention policy.

## Run-time cost (instances launched from the AMI)

This AMI doesn't add meaningful run-time cost over a stock AL2023 AMI - it's
the same OS, just hardened. The only incremental items:

| Item | Cost driver |
|---|---|
| auditd logging | Slightly higher disk I/O/CPU from the audit rule set; negligible on modern instance types |
| CloudWatch Agent | **CloudWatch Logs**: ~$0.50/GB ingested + $0.03/GB-month stored (after the free tier). **CloudWatch custom metrics**: ~$0.30/metric/month past the free tier - this project's agent config publishes a small, fixed set of host metrics (CPU, memory, disk, diskio, netstat), not high-cardinality custom metrics, so expect low single-digit dollars/month/instance. |
| AIDE daily check | CPU/IO burst once a day; size depends on filesystem content, typically seconds to low minutes on a golden image |
| EBS encryption (KMS) | $1/month per CMK if you bring your own key, plus $0.03 per 10,000 KMS API requests; free if you use the AWS-managed `aws/ebs` key |

For a typical small fleet (tens of instances), expect low-tens-of-dollars a
month in CloudWatch spend attributable to this project's logging/metrics
config, on top of whatever your workload already costs to run.
