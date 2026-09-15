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
terragrunt run --all plan
terragrunt run --all --no-auto-approve apply
```

To manage a single environment after shared already exists:

```bash
cd terragrunt/gke-prod # or terragrunt/gke-gitops
terragrunt run --all plan
terragrunt run --all --no-auto-approve apply
```

`gke-gitops/addons` depends on `gke-prod/addons`, so apply production
addons before GitOps addons if you are not using `run --all` from the root.
On the first M7 bootstrap, apply `gke-prod/addons` before the root apply so
its generated TLS/auth outputs exist. GitOps uses placeholders only for
`plan` and `validate`; apply never permits mock outputs.

## Monitoring

The addon stacks pin `kube-prometheus-stack` 90.2.0. Prometheus and
Alertmanager run in both clusters; Grafana runs only in GitOps. Prometheus
retains up to seven days or 15 GB on a 20 GiB `standard-rwo` volume.
Alertmanager uses 5 GiB per cluster and Grafana uses 5 GiB.

Prod Prometheus is available to GitOps Grafana through an internal load
balancer restricted to the GitOps node and pod CIDRs. An nginx proxy provides
TLS and basic authentication. Its generated credentials and private key are
sensitive values in the protected addon states and Kubernetes Secrets, not
Git.

After applying the addon units, connect to private Grafana locally:

```bash
gcloud container clusters get-credentials gke-gitops \
  --region us-east1 --project johnydev
kubectl -n monitoring get pods,pvc
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
kubectl -n monitoring port-forward service/monitoring-grafana 3000:80
```

Open `http://127.0.0.1:3000`, sign in as `admin`, and verify the `GitOps` and
`Prod` data sources and the **Multi-cluster overview** dashboard. Grafana has
no public Service or Ingress.

To test Alertmanager firing and resolution, port-forward the local
Alertmanager and post a temporary alert with `/api/v2/alerts`; post the same
labels again with an expired `endsAt` to resolve it. Verify each cluster
independently because each Prometheus routes to its local Alertmanager.

```bash
kubectl -n monitoring port-forward \
  service/monitoring-kube-prometheus-alertmanager 9093:9093
curl -H 'Content-Type: application/json' -d \
  '[{"labels":{"alertname":"M7Test","severity":"warning"},"endsAt":"2099-01-01T00:00:00Z"}]' \
  http://127.0.0.1:9093/api/v2/alerts
curl -H 'Content-Type: application/json' -d \
  '[{"labels":{"alertname":"M7Test","severity":"warning"},"endsAt":"2000-01-01T00:00:00Z"}]' \
  http://127.0.0.1:9093/api/v2/alerts
```
