# AI Platform Infra

A focused, production-shaped **cloud infrastructure + Kubernetes + CI/CD**
project on AWS. The whole point of this project is the infra layer itself
— how you provision a VPC, an EKS cluster, IAM/OIDC trust, a container
registry, and a gated deployment pipeline, correctly and without
overbuilding.

The app it deploys is deliberately minimal — a placeholder FastAPI
service with a `/health` endpoint. **The app is not the point.** Swap it
for anything containerized without touching the infra.

> This project is one of three related, but intentionally **isolated**
> projects:
> - **AI-platform-infra** (this one) — cloud infra, Kubernetes infra,
>   generic deployment
> - **llm-serving-platform** — serving vLLM as a distribution engine
>   (routing, replicas, load balancing)
> - **gpu-inference-platform** — GPU internals (KV cache, VRAM,
>   tokenization, batching)
>
> Each has its own infra, sized to what it actually needs — this project
> does not assume or depend on the other two.

## What this project is NOT

- Not an LLM project. There's no model, no GPU, no vLLM here — see
  `llm-serving-platform` and `gpu-inference-platform` for that.
- Not a GitOps demo. No ArgoCD, no Helm chart for the app. Deployment is
  a direct, explicit, gated `kubectl apply` — simpler to reason about for
  a project this size, and it's what actually got built and tested here.
- Not multi-environment. Only `dev` exists. The Terraform structure
  supports adding `staging`/`prod` later by copying the `dev` folder, but
  they aren't built here — no reason to carry infra nobody's using.

## Architecture — current (dev / learning grade)

```
                              ┌──────────────────────┐
                              │   GitHub Actions     │
                              │  (OIDC, no static    │
                              │   AWS keys)          │
                              └──────────┬───────────┘
                                         │
                        verify → build+scan → deploy (1 manual approval)
                                         │
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │         VPC (single account)            │
                    │         2 AZs, 1 NAT Gateway            │
                    │                                         │
                    │  ┌───────────────┐   ┌───────────────┐  │
                    │  │ Public Subnet │   │ Public Subnet │  │
                    │  │   (AZ-a)      │   │   (AZ-b)      │  │
                    │  └──────┬────────┘   └───────────────┘  │
                    │         │ NAT (single, no HA)           │
                    │  ┌──────▼────────┐   ┌───────────────┐  │
                    │  │Private Subnet │   │Private Subnet │  │
                    │  │   (AZ-a)      │   │   (AZ-b)      │  │
                    │  │  EKS nodes    │   │  (unused)     │  │
                    │  └───────────────┘   └───────────────┘  │
                    └─────────────────────────────────────────┘
                                         │
                                         ▼
                          EKS Cluster (single node group,
                          t3.medium x2, no autoscaler)
                                         │
                                         ▼
                    sample-app (2 replicas) → LoadBalancer Service
                    (Classic ELB, public, no WAF, no TLS)
```

This is one environment (`dev`), one AWS account, one NAT Gateway (a
single point of failure), one fixed-size node group (no autoscaling), no
TLS/WAF, and a single manual approval as the only deploy gate. That's a
deliberate choice for a project whose point is demonstrating the infra
layer cleanly — not a gap to be embarrassed about. See below for what
changes if this needed to actually serve production traffic.

## Architecture — production grade (not built here, documented for reference)

```
                        ┌───────────────────────────┐
                        │      GitHub Actions       │
                        │  OIDC + branch protection │
                        │  + required PR reviews    │
                        └──────────────┬────────────┘
                                       │
                verify → test → scan → build → push
                                       │
                    ┌──────────────────┴───────────────────┐
                    ▼                                      ▼
            Deploy to STAGING                     Deploy to PROD
            (auto, on merge to main)         (manual gate + canary/blue-green)
                    │                                      │
                    ▼                                      ▼
        ┌────────────────────────┐            ┌───────────────────────────┐
        │  Staging AWS Account   │            │   Production AWS Account  │
        │  (separate from prod)  │            │                           │
        └────────────────────────┘            └─────────────┬─────────────┘
                                                            │
                                    ┌───────────────────────┴──────────────────────┐
                                    │            VPC — 3 AZs                       │
                                    │   NAT Gateway PER AZ (HA, no single point    │
                                    │              of failure)                     │
                                    │                                              │
                                    │  Public (a/b/c)         Private (a/b/c)      │
                                    │  ALB + WAF                EKS nodes          │
                                    │       │                 (multi-node-group:   │
                                    │       │                  system + app +      │
                                    │       │                  spot/on-demand mix) │
                                    └───────┼──────────────────────┬───────────────┘
                                            │                      │
                                            ▼                      ▼
                                    ┌───────────────┐    ┌──────────────────────┐
                                    │  AWS WAF      │    │ Cluster Autoscaler / │
                                    │  (rate limit, │    │ Karpenter            │
                                    │   bot rules)  │    │ (scale on demand)    │
                                    └───────┬───────┘    └──────────────────────┘
                                            │
                                    ┌───────▼────────┐
                                    │ ALB Ingress    │
                                    │ Controller     │
                                    │ + cert-manager │
                                    │ (TLS, ACM)     │
                                    └───────┬────────┘
                                            │
                        ┌───────────────────┼────────────────────┐
                        ▼                   ▼                    ▼
                ┌───────────────┐   ┌───────────────┐    ┌────────────────┐
                │ sample-app    │   │ HPA           │    │ Pod Disruption │
                │ (N replicas,  │   │ (auto-scale   │    │ Budget         │
                │ pod anti-     │   │  on CPU/mem)  │    │ (min available)│
                │ affinity)     │   └───────────────┘    └────────────────┘
                └───────────────┘

        Cross-cutting (all namespaces):
        ├── Network Policies (default-deny, explicit allow)
        ├── Pod Security Standards (restricted)
        ├── OPA/Kyverno policies (image provenance, no :latest, resource limits required)
        ├── External Secrets Operator → AWS Secrets Manager (properly wired, not a stub)
        ├── Centralized logging → CloudWatch Logs / OpenSearch
        ├── Prometheus + Grafana + Alertmanager (paging on-call)
        ├── Velero → scheduled EKS backups to S3
        └── Cost tagging + AWS Budgets alerts per environment
```

### Dev → production upgrade table

| Area | Dev (current) | Production (proposed) |
|---|---|---|
| AWS accounts | 1 account, 1 env | Separate accounts per env (dev/staging/prod) — blast-radius isolation |
| AZs | 2 | 3 (EKS best practice, better failure tolerance) |
| NAT Gateway | 1 (single point of failure) | 1 per AZ (HA) |
| Node scaling | Fixed 2 nodes, manual | Cluster Autoscaler / Karpenter, multiple node groups (system vs app, spot mix for cost) |
| Ingress | Raw LoadBalancer Service, HTTP only | ALB Ingress Controller + WAF + TLS via cert-manager/ACM |
| Deploy strategy | Direct rolling update | Canary or blue-green, automated staging + gated prod |
| Secrets | Plain Kubernetes Secrets | External Secrets Operator → AWS Secrets Manager |
| Network security | None (flat pod network) | Network Policies (default-deny), Pod Security Standards |
| Policy enforcement | None | OPA/Kyverno — block `:latest` tags, unscanned images, missing resource limits |
| Logging | Pod logs via `kubectl logs` only | Centralized (CloudWatch/OpenSearch), retained + searchable |
| Alerting | None | Alertmanager → PagerDuty/Slack, real on-call paging |
| Backup/DR | None | Velero scheduled backups, tested restore runbook |
| CI/CD gates | 1 manual approval | Branch protection + required reviews + staging auto-deploy + prod manual gate |
| Cost control | None | Budgets + alerts, spot for non-critical node pools |

Production topology costs meaningfully more to run (multiple NAT
Gateways, a second AWS account, WAF, extra controllers) — roughly 2-3x
this project's baseline if left running continuously. That trade-off is
why this repo intentionally stays at the dev-grade architecture: it's
enough to demonstrate the infra layer correctly without paying for
capacity nobody's using. Treat the table above as the actual next-steps
list if this ever needs to hold production traffic.

## What's actually here

| Layer | What |
|---|---|
| **Networking** | VPC, 2 AZs, public + private subnets, IGW, NAT Gateway, route tables |
| **Kubernetes** | Amazon EKS, managed node group, IAM roles for cluster + nodes |
| **Registry** | Amazon ECR, image scanning on push, lifecycle policy (keep last 10) |
| **State management** | Terraform remote state — S3 backend + DynamoDB locking, bootstrapped separately from the rest |
| **CI/CD auth** | GitHub OIDC → scoped IAM role (no long-lived AWS keys in GitHub secrets) |
| **Cluster access for CI** | EKS access entry, scoped to the `sample-app`/`monitoring` namespaces via `AmazonEKSEditPolicy` — not cluster-admin |
| **Security scanning** | Trivy, gated in CI (build fails on HIGH/CRITICAL CVEs) |
| **Monitoring (optional)** | Prometheus + Grafana via their standard Helm charts, `ServiceMonitor` wired to the sample app |
| **Sample app** | FastAPI, `/health` endpoint, tests, Dockerfile |

## Repository structure

```
AI-platform-infra/
├── .github/workflows/
│   └── deploy.yml            # verify-infra -> build-and-push -> deploy (gated)
├── app/
│   └── main.py                # placeholder app - swap for anything containerized
├── tests/
│   └── test_main.py
├── docker/
│   └── Dockerfile
├── kubernetes/base/
│   ├── namespace.yaml
│   ├── deployment.yaml        # image is a template placeholder, filled at deploy time
│   └── service.yaml
├── monitoring/
│   ├── prometheus/            # install.sh + values.yaml + ServiceMonitor
│   └── grafana/                # install.sh + values.yaml + datasource
├── security/trivy/
│   └── config.yaml
├── terraform/
│   ├── bootstrap/              # S3 + DynamoDB remote state (run once)
│   ├── environments/dev/       # composes the modules below into a real deployment
│   └── modules/
│       ├── vpc/
│       ├── iam/
│       ├── ecr/
│       ├── eks/
│       └── github-oidc/        # GitHub Actions trust + scoped IAM role
├── scripts/
│   ├── setup-infra.sh          # central: full setup, one command
│   ├── destroy-infra.sh        # central: full teardown, one command
│   ├── verify-infra.sh         # human-readable health check
│   ├── ci-check-infra.sh       # strict, CI-only health check (never applies/destroys)
│   ├── build.sh
│   └── deploy.sh
├── requirements.txt            # runtime deps (ships in the image)
├── requirements-dev.txt        # + pytest, for CI/local testing only
├── Makefile
└── .dockerignore                # at repo root - this is the actual Docker build context
```

## Prerequisites

- AWS CLI v2, configured (`aws configure`, verify with `aws sts get-caller-identity`)
- Terraform >= 1.8
- kubectl
- Docker
- `envsubst` (part of `gettext` — usually already installed on Linux/Mac)
- Python 3.12 (for running the sample app / tests locally)

## Setup

One command does the whole thing — Terraform state backend, VPC, IAM,
ECR, EKS, and the GitHub OIDC trust role, in the right order:

```bash
scripts/setup-infra.sh your-github-org/your-repo-name
```

It prints the GitHub Actions role ARN at the end. Copy it into a GitHub
secret named `AWS_DEPLOY_ROLE_ARN` (repo → Settings → Secrets and
variables → Actions), then create a `production` GitHub Environment
(Settings → Environments) with yourself as a required reviewer — that's
the manual approval gate the `deploy` job waits on.

Check everything's healthy:

```bash
scripts/verify-infra.sh
```

## Deploying the sample app

Either push to `main` and let the pipeline handle it (build → scan →
push → wait for your approval → deploy), or do it by hand:

```bash
scripts/build.sh

aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  "${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com"

docker tag sample-app:latest \
  "${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/sample-app:latest"

docker push \
  "${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/sample-app:latest"

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/sample-app:latest" \
  scripts/deploy.sh
```

## Monitoring (optional)

```bash
make monitor
```

Installs Prometheus and Grafana via their standard community Helm charts
(this is normal, expected use of Helm for third-party charts — the thing
that got removed was a custom Helm chart wrapping the sample app, which
was redundant with the raw manifests in `kubernetes/base/`).

Grafana default credentials are `admin` / `admin123` — this is a dev
default, not meant for anything beyond local testing. Access via:

```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```

## Cost

Nothing here is free-tier-invisible. Running costs while the dev
environment is up:

| Resource | Approx. cost |
|---|---|
| EKS control plane | ~$0.10/hr |
| 2x `t3.medium` nodes (default) | ~$0.083/hr combined |
| NAT Gateway | ~$0.045/hr + data processing |
| Load Balancer (once `sample-app` is deployed) | ~$0.025/hr + data |
| ECR, S3, DynamoDB | Small, usage-based |

There's no GPU here, so the cost profile is far lower than the other two
projects — but it's still real money if left running. Tear it down when
you're not actively using it:

```bash
scripts/destroy-infra.sh
```

This leaves the Terraform state backend (S3/DynamoDB) alone by default,
since destroying it loses your state history — see the script's output
for how to remove that too if you really want a clean slate.

## Security notes

- CI/CD authenticates to AWS via OIDC — no static AWS keys stored in
  GitHub secrets.
- The CI role's EKS access is scoped via an access entry + namespace
  policy, not cluster-admin.
- ECR push permissions for the CI role are scoped to the one repository.
- Every image is scanned by Trivy in CI (fails the build on HIGH/CRITICAL)
  and by ECR's own scan-on-push.
- Deploys require a human approval (GitHub Environment reviewer) before
  anything touches the cluster.
- Not addressed here (intentionally out of scope for this project):
  Kubernetes NetworkPolicies, Pod Security Standards enforcement, secrets
  management beyond plain Kubernetes Secrets (no Vault/External Secrets —
  that was in the original draft but never actually wired to anything, so
  it was removed rather than left as dead config).

## What was removed, and why

This project started life as a broader "LLMOps platform" draft that had
grown past what it could actually demonstrate working end to end. These
were removed as part of tightening the focus back to infra:

- **ArgoCD / GitOps** — added a whole extra moving part (a second
  deployment mechanism reacting to Git commits) for a project whose point
  is the infra, not deployment philosophy. The CI/CD pipeline now deploys
  directly and explicitly.
- **A custom Helm chart for the app** — duplicated the raw Kubernetes
  manifests in `kubernetes/base/` with no real difference in what got
  deployed. Kept the raw manifests; dropped the chart.
- **`terraform/environments/staging` and `prod`** — never going to be
  applied in a demo project; kept as a documented pattern (copy `dev`)
  rather than as dead, unmaintained duplicate state.
- **`security/external-secrets/`** — two empty YAML files, never wired to
  an actual secret store. Removed rather than left as a misleading stub.
- **`output.yaml`** at the repo root — a leftover `helm template` dump,
  not meant to be committed.
- **Both GitHub Actions workflows were entirely commented out** in the
  original draft — meaning the CI/CD pipeline the README described didn't
  actually run. Replaced with one real, working workflow.
- **Missing app source** — the Dockerfile referenced `app/main.py` and
  `requirements.txt` that didn't exist in the repo, so the image never
  actually built. Added the minimal placeholder app described above.
- **`.dockerignore` was inside `docker/`** while the build context is the
  repo root — Docker never actually read it, so `.git`, Terraform state
  config, and docs were all being sent into the build context
  unnecessarily. Moved to the repo root where Docker actually looks for
  it.

## License

MIT — see `LICENSE`.
