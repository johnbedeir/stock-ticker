# Application guide

Requires Go 1.27+, Docker, and an
[Alpha Vantage API key](https://www.alphavantage.co/support/#api-key).

## Run locally

```bash
cd app
APIKEY=your_key SYMBOL=MSFT NDAYS=7 go run ./cmd/server
```

Open <http://localhost:8080/>. Health endpoints: `/health`, `/ready`, and
`/metrics`.

## Test

```bash
cd app
go test -race ./...
go vet ./...
```

## Run with Docker

From the repository root:

```bash
docker build -t stock-ticker:local .
docker run --rm -p 8080:8080 \
  -e APIKEY=your_key -e SYMBOL=MSFT -e NDAYS=7 \
  stock-ticker:local
```

Open <http://localhost:8080/>.

## Run with Minikube

From the repository root:

```bash
minikube start --driver=docker
minikube addons enable ingress

docker build -t stock-ticker:local .
minikube image load stock-ticker:local

kubectl apply -f kubernetes/namespace.yaml
kubectl -n stock-ticker create secret generic stock-ticker-api \
  --from-literal=APIKEY=your_key
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml

kubectl -n ingress-nginx port-forward \
  service/ingress-nginx-controller 18081:80
```

In another terminal:

```bash
curl -H 'Host: stock-ticker.local' http://127.0.0.1:18081/
```

`kubernetes/secret.example.yaml` is a template only; do not commit a real API
key.

## Published image

Main-branch CI publishes to a public Artifact Registry repository:

```text
us-east1-docker.pkg.dev/johnydev/stock-ticker/stock-ticker:<full-source-SHA>
us-east1-docker.pkg.dev/johnydev/stock-ticker/stock-ticker:v1.0.0
```

```bash
docker pull us-east1-docker.pkg.dev/johnydev/stock-ticker/stock-ticker:v1.0.0
```

CI publishes the source-SHA tag. Publishing a GitHub Release adds the matching
version tag to that same tested image digest.
