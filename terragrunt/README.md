# GCP infrastructure

Terraform runs locally through Terragrunt. GitHub Actions never runs
Terraform, Terragrunt, Helm deployment, or `kubectl`.

## Authentication

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project johnydev
gcloud components install gke-gcloud-auth-plugin
export PATH="$(gcloud info --format='value(installation.sdk_root)')/bin:$PATH"
```

Install the `gke-gcloud-auth-plugin` gcloud component before running addon
units. No service-account JSON key or operator impersonation is used. GitHub's
repository-scoped principal can impersonate only the CI service account
through Workload Identity Federation. Update `operator_cidr` in `root.hcl` if
the operator's public IP changes.

## State

The protected, versioned bucket `johnydev-stock-ticker-tfstate` is retained
outside workload teardown. Units use these prefixes:

- `shared`
- `gke-gitops/cluster`
- `gke-prod/cluster`
- `gke-prod/addons`
- `gke-gitops/addons`

## Order

Apply everything from the `terragrunt/` root. Terragrunt resolves
dependencies automatically: shared, clusters, then addons.

```bash
cd terragrunt
terragrunt run --all -- plan
terragrunt run --all --no-auto-approve -- apply
```

To manage a single environment after shared already exists:

```bash
cd terragrunt/gke-prod # or terragrunt/gke-gitops
terragrunt run --all -- plan
terragrunt run --all --no-auto-approve -- apply
```

`gke-gitops/addons` depends on `gke-prod/cluster`, so apply production
before GitOps addons if you are not using `run --all` from the root.
