# Production releases

Every non-values-only push to `main` is tested, scanned, built, and published
by `CI`. After that run succeeds, `Release` reads its `release-metadata`
artifact and opens or updates one pull request from
`release/promote-production`.

The release pull request changes only:

```text
helm/stock-ticker-chart/values.yaml
```

Merging that pull request is the production approval. CI still reports its
normal required checks but skips rebuilding and publishing the unchanged
application image. Argo CD then notices the new digest on `main` and performs
the rollout. The workflows never run `kubectl`, `helm install`, or Terraform.

## GitHub App

Create and install a repository-scoped GitHub App with only these repository
permissions:

- Contents: read and write
- Pull requests: read and write
- Metadata: read

Generate a private key and add these Actions repository secrets:

- `RELEASE_APP_ID`: the App ID
- `RELEASE_APP_PRIVATE_KEY`: the complete PEM private key

The App token makes the release pull request behave like a normal contributor
PR, so required CI checks run. Do not replace it with a personal access token.

Protect `main` and require the CI checks before merge. Auto-merge is optional;
without it, merging the release PR is the deliberate promotion step.

## Safety behavior

Release runs are serialized. Metadata must match the successful triggering CI
run and the expected Artifact Registry repository. A source commit must still
belong to `main`, and a source older than either the deployed or pending source
is ignored. A successful values-only CI run has no publish job or release
artifact, so it cannot create a promotion loop.

To roll back, revert the merged values commit. Argo CD will restore the prior
immutable digest.

## Publish versioned release artifacts

Publishing a GitHub Release does two things:

1. Tags the already-tested Docker image as `vX.Y.Z` using the digest in
   `helm/stock-ticker-chart/values.yaml`. It does not rebuild the image.
2. Publishes the matching OCI Helm chart to the private
   `stock-ticker-charts` Artifact Registry repository.

First apply the shared Terraform changes:

```bash
cd terragrunt/shared
terragrunt plan
terragrunt apply
```

Then publish a release from `main` after its image promotion pull request has
been merged:

```bash
git checkout main
git pull --ff-only
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 --verify-tag --generate-notes
```

The tag must use `vMAJOR.MINOR.PATCH`. The `Release` workflow publishes:

```text
us-east1-docker.pkg.dev/johnydev/stock-ticker/stock-ticker:v1.0.0
oci://us-east1-docker.pkg.dev/johnydev/stock-ticker-charts/stock-ticker-chart:1.0.0
```

Verify the workflow and pull both artifacts:

```bash
gh run list --workflow helm-release.yml --limit 5

docker pull \
  us-east1-docker.pkg.dev/johnydev/stock-ticker/stock-ticker:v1.0.0

gcloud auth print-access-token | helm registry login \
  -u oauth2accesstoken \
  --password-stdin https://us-east1-docker.pkg.dev

helm pull \
  oci://us-east1-docker.pkg.dev/johnydev/stock-ticker-charts/stock-ticker-chart \
  --version 1.0.0
helm show chart stock-ticker-chart-1.0.0.tgz
```

Artifact Registry rejects a second push of the same chart version. Publish a
new patch version instead. Argo CD continues to deploy the chart from Git;
publishing the OCI package does not trigger a production deployment.
