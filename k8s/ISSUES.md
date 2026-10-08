# Task 2 — Kubernetes Deployment Issues

## Issues in the Original Manifest

| # | Issue | Why it matters |
|---|---|---|
| 1 | `namespace: auctions` may not exist | Deployment/Service will fail if the namespace hasn't been created. |
| 2 | Deployment label mismatch | Deployment selects `app: auction-api`, but Pods have `app: auctions-api`, so the Deployment selector doesn't match its Pods. |
| 3 | Service selector mismatch with Pods | Service looks for `app: auction-api`, while Pods have `app: auctions-api`; therefore the Service gets no endpoints. |
| 4 | Container listens on `8080` | The application declares `containerPort: 8080`. |
| 5 | Readiness probe checks port `80` | The application is on `8080`, so the `/health` probe fails. |
| 6 | Service `targetPort: 80` | Traffic is sent to port 80, but the container listens on 8080. |
| 7 | `latest` image tag | `latest` is mutable and makes deployments non-reproducible. |
| 8 | Hard-coded DB password | Credentials are exposed directly in the Kubernetes manifest/repository. |
| 9 | Only 1 replica | A single Pod creates a single point of failure. |
| 10 | No resource requests/limits | The workload can consume unpredictable CPU/memory and affect other workloads. |
| 11 | No liveness probe | Kubernetes cannot automatically determine whether a stuck application should be restarted. |
| 12 | No startup probe | Slow-starting applications may be considered unhealthy before they finish starting. |
| 13 | No security context | The container has no explicit non-root or other runtime security controls. |
| 14 | No image pull configuration | If the ACR is private, AKS needs appropriate authentication/identity or image-pull configuration. |
| 15 | No `imagePullPolicy` | With a mutable tag such as `latest`, image behavior can be less predictable. |
| 16 | No rolling-update configuration | Production deployments should explicitly control rollout behavior. |
| 17 | No Pod disruption protection | During voluntary disruptions, all API replicas could potentially become unavailable. |
| 18 | No NetworkPolicy | There is no Kubernetes-level restriction on which Pods can communicate with the API. |
