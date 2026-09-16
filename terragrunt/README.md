# GCP infrastructure

Terragrunt runs Terraform locally and builds the shared GCP resources, two GKE
clusters, Argo CD, monitoring, and the production application.

## Requirements

- Terraform 1.15.5
- Terragrunt 1.1.x
- Google Cloud CLI with `gke-gcloud-auth-plugin`
- `kubectl`

Set your public IP before running Terragrunt:

```bash
export OPERATOR_CIDR="$(curl -fsS https://checkip.amazonaws.com)/32"
```

## Authenticate

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project johnydev
gcloud components install gke-gcloud-auth-plugin
export PATH="$(gcloud info --format='value(installation.sdk_root)')/bin:$PATH"
```

## Build the infrastructure

Terragrunt applies shared resources, clusters, production addons, and GitOps
addons in dependency order.

```bash
cd terragrunt
terragrunt run --all plan
terragrunt run --all --no-auto-approve apply
```

Manage one cluster after the shared resources exist:

```bash
cd terragrunt/gke-prod # or terragrunt/gke-gitops
terragrunt run --all plan
terragrunt run --all --no-auto-approve apply
```

Terraform state is stored in the protected
`johnydev-stock-ticker-tfstate` GCS bucket.

The shared stack creates two private Artifact Registry repositories:

- `stock-ticker` — container images
- `stock-ticker-charts` — immutable OCI Helm chart packages

The GitHub Actions CI service account can publish to both repositories. Argo
CD continues to read the production chart from Git.

## Add the application secret

```bash
gcloud container clusters get-credentials gke-prod \
  --region us-east1 --project johnydev
read -s APIKEY
kubectl -n stock-ticker create secret generic stock-ticker-api \
  --from-literal=APIKEY="$APIKEY" \
  --dry-run=client -o yaml | kubectl apply -f -
unset APIKEY
```

## Update the DNS Zone Editor

Get the production ingress IP:

```bash
cd terragrunt/gke-prod/addons
terragrunt output -raw stock_ticker_ingress_ip
```

Create this record in the DNS provider's Zone Editor:

- Type: `A`
- Name/Host: `stock`
- Value: the ingress IP from the command above
- TTL: `300` or the provider default

Remove any conflicting `stock` A, AAAA, or CNAME record, then verify:

```bash
dig +short stock.johnydev.com
curl https://stock.johnydev.com/
```

The managed certificate may take several minutes to become active.

## Set up Slack alerts

Create a Slack Incoming Webhook, copy its URL, and add it to the production
monitoring namespace:

```bash
gcloud container clusters get-credentials gke-prod \
  --region us-east1 --project johnydev

read -s SLACK_WEBHOOK_URL
kubectl -n monitoring create secret generic stock-ticker-slack-webhook \
  --from-literal=url="$SLACK_WEBHOOK_URL" \
  --dry-run=client -o yaml | kubectl apply -f -
unset SLACK_WEBHOOK_URL
```

Test the Slack route:

```bash
kubectl -n monitoring port-forward \
  service/monitoring-kube-prometheus-alertmanager 9093:9093
```

In another terminal, fire and resolve a temporary alert:

```bash
curl -H 'Content-Type: application/json' -d \
  '[{"labels":{"alertname":"StockTickerTest","namespace":"stock-ticker","severity":"warning"},"endsAt":"2099-01-01T00:00:00Z"}]' \
  http://127.0.0.1:9093/api/v2/alerts

curl -H 'Content-Type: application/json' -d \
  '[{"labels":{"alertname":"StockTickerTest","namespace":"stock-ticker","severity":"warning"},"endsAt":"2000-01-01T00:00:00Z"}]' \
  http://127.0.0.1:9093/api/v2/alerts
```

## Open Grafana

```bash
gcloud container clusters get-credentials gke-gitops \
  --region us-east1 --project johnydev
kubectl -n monitoring get secret monitoring-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
kubectl -n monitoring port-forward service/monitoring-grafana 3000:80
```

Open <http://127.0.0.1:3000> and sign in as `admin`.

## Open Argo CD

```bash
gcloud container clusters get-credentials gke-gitops \
  --region us-east1 --project johnydev
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode
kubectl -n argocd port-forward service/argocd-server 8443:443
```

Open <https://127.0.0.1:8443>, sign in as `admin`, and verify that
`stock-ticker` is **Synced** and **Healthy**.

## Tear down

Do not use `terragrunt run --all destroy`. Remove resources in this order so
Argo CD can clean up the application before either cluster is deleted.

Back up monitoring PVC data first if it must be retained.

### 1. Delete the application

```bash
gcloud container clusters get-credentials gke-gitops \
  --region us-east1 --project johnydev
kubectl -n argocd delete application stock-ticker \
  --wait=true --timeout=15m
```

The Argo CD finalizer deletes the application resources from production.

### 2. Destroy the addon units

Destroy GitOps addons first, then production addons:

```bash
cd "$(git rev-parse --show-toplevel)/terragrunt/gke-gitops/addons"
terragrunt plan -destroy -out=tfplan
terragrunt apply tfplan
rm -f tfplan

cd ../../gke-prod/addons
terragrunt plan -destroy -out=tfplan
terragrunt apply tfplan
rm -f tfplan
```

### 3. Destroy the cluster units

Both clusters have deletion protection. Apply `false`, then destroy each
cluster:

```bash
cd "$(git rev-parse --show-toplevel)/terragrunt/gke-gitops/cluster"
terragrunt plan -out=tfplan -var='deletion_protection=false'
terragrunt apply tfplan
rm -f tfplan
terragrunt plan -destroy -out=tfplan -var='deletion_protection=false'
terragrunt apply tfplan
rm -f tfplan

cd ../../gke-prod/cluster
terragrunt plan -out=tfplan -var='deletion_protection=false'
terragrunt apply tfplan
rm -f tfplan
terragrunt plan -destroy -out=tfplan -var='deletion_protection=false'
terragrunt apply tfplan
rm -f tfplan
```

### 4. Destroy dedicated shared resources

Review the shared destroy plan. Run it only if the VPC, registries, and IAM
resources are dedicated to this exercise:

```bash
cd "$(git rev-parse --show-toplevel)/terragrunt/shared"
terragrunt plan -destroy -out=tfplan
terragrunt apply tfplan
rm -f tfplan
```

Finally, remove the external DNS record and revoke the Slack webhook and API
key if they were created only for this exercise. The Terraform state bucket is
intentionally preserved. Published registries may need to be emptied before
Terraform can delete them.
