# Run locally

Requires Go 1.23+ and an [Alpha Vantage API key](https://www.alphavantage.co/support/#api-key).

```bash
cd app
SYMBOL=MSFT NDAYS=7 APIKEY=your_key go run ./cmd/server
```

Then open `http://localhost:8080/`. Optional checks: `/health`, `/ready`, `/metrics`.

## Tests

```bash
cd app
go test -race ./...
go vet ./...
```

## Docker

From the repository root:

```bash
docker build -t stock-ticker:local .
docker run --rm -p 8080:8080 \
  -e SYMBOL=MSFT -e NDAYS=7 -e APIKEY=your_key \
  stock-ticker:local
```

## Minikube

From the repository root, with Docker Desktop running:

```bash
minikube start --driver=docker
minikube addons enable ingress
docker build -t stock-ticker:local .
minikube image load stock-ticker:local

kubectl apply -f kubernetes/namespace.yaml
export APIKEY=your_key
kubectl -n stock-ticker create secret generic stock-ticker-api \
  --from-literal=APIKEY="$APIKEY"
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl -n stock-ticker rollout status deployment/stock-ticker
```

Do not apply `secret.example.yaml`; it only documents the required secret shape.

For Minikube's Docker driver on macOS, forward the ingress controller:

```bash
kubectl -n ingress-nginx port-forward service/ingress-nginx-controller 18081:80
curl -H 'Host: stock-ticker.local' http://127.0.0.1:18081/
```

Tested with Minikube 1.39.0, Kubernetes 1.35.1, Docker driver, and
ingress-nginx controller 1.15.1 on macOS.
