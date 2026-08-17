# Splunk Observability Cloud dashboard for KubeInvaders

Equivalent of [`confs/grafana/KubeInvadersDashboard.json`](../grafana/KubeInvadersDashboard.json), rebuilt for Splunk Observability Cloud. There's no JSON-import path between the two systems, so this is Terraform using the [`splunk-terraform/signalfx`](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest) provider.

## Prerequisites

1. **A Splunk O11y API token with dashboard/chart write access.** This is *not* the ingest-only access token used by the otel collector (`splunkObservability.accessToken` in the main collector's Helm values, or the `SPLUNK_ACCESS_TOKEN` secret used by the `otelSidecar`) — that token can only ingest data, not create dashboards. Generate an org or user API token from Splunk O11y under Settings → Access Tokens.

2. **The source metrics must actually exist.** These panels read from KubeInvaders' own `/metrics` endpoint (`chaos_jobs_node_count`, `deleted_pods_total`, `chaos_node_jobs_total`, `deleted_namespace_pods_count`), which is only populated once a chaos session has actually run — the app writes these counters to Redis as chaos jobs happen. Enable the scrape via the Helm chart (`helm-charts/kubeinvaders`):

   ```bash
   helm upgrade kubeinvaders ./helm-charts/kubeinvaders -n kubeinvaders \
     --set otelSidecar.enabled=true \
     --set otelSidecar.accessTokenSecretName=<your-secret-name>
   ```

   Then run a chaos session in the game (or just let auto-pilot run for a bit) before expecting data in the dashboard.

## Usage

```bash
cd confs/splunk-o11y/terraform
terraform init
terraform apply -var="splunk_api_token=<your-api-token>" -var="splunk_realm=us1"
```

Or set `TF_VAR_splunk_api_token` / `TF_VAR_splunk_realm` as environment variables instead of passing `-var`.

## Panel mapping

| Grafana panel | Type | Splunk O11y equivalent |
|---|---|---|
| Chaos jobs | Graph | `signalfx_time_chart` — `chaos_jobs_node_count`, delta rollup by node |
| Killed pods | Stat | `signalfx_single_value_chart` — `deleted_pods_total` |
| Chaos jobs against nodes | Stat | `signalfx_single_value_chart` — `chaos_node_jobs_total` |
| Killed pods | Graph (by namespace) | `signalfx_time_chart` — `deleted_namespace_pods_count`, delta rollup by namespace |
| Chaos jobs count | Bar gauge | `signalfx_list_chart` — `chaos_jobs_node_count` by node |
| Killed pods count | Bar gauge | `signalfx_list_chart` — `deleted_namespace_pods_count` summed by namespace |

`rollup='delta'` on a cumulative counter in SignalFlow is the equivalent of Prometheus's `increase()` over the chart's resolution window, used for the two "Chaos jobs"/"Killed pods" trend panels; the stat and bar-gauge panels read the raw counter value directly, same as the original's `instant: true` queries.

## Detector: available pods below desired

`signalfx_detector.deployment_available_below_desired` fires when **any deployment in the cluster** has fewer available pods than its desired replica count for 5 minutes straight — e.g. a CrashLoopBackOff, a failed rollout, or the cluster running out of resources to schedule pods on. It's not scoped to a single namespace or deployment, so it also catches the kubeinvaders Deployment itself if `deployment.replicaCount` is set too low relative to how aggressively the chaos game kills pods.

Unlike the dashboard panels above, this reads `kubernetes.deployment.available` / `kubernetes.deployment.desired`, which come from the **cluster-wide** OTel Collector's `k8s_cluster` receiver (the one referenced in `helm-charts/kubeinvaders/values.yaml`'s `additionalLabels` comment), not from the app's own `/metrics` endpoint. That collector must already be deployed against the cluster with `clusterName` set — it's out of scope for this repo.

```bash
terraform apply \
  -var="splunk_api_token=<your-api-token>" \
  -var="splunk_realm=us1" \
  -var='detector_notifications=["Email,you@example.com"]'
```

Notes:
- `detector_notifications` defaults to `[]` (a detector with no notification recipients — it will show as triggered in the UI but won't page anyone). See the [`signalfx_detector` docs](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector#notification-format) for the recipient string format for Email/Slack/PagerDuty/etc.
- To scope the detector back down to a single namespace or deployment, add `filter('kubernetes_namespace', '...')` / `filter('deployment', '...')` to the `data(...)` calls in `main.tf`. Those dimension names match Splunk's built-in Kubernetes Navigator content as of this writing; if the detector shows no data after adding filters, check **Metric Finder** in Splunk O11y for the exact dimension names your collector version reports (they occasionally shift, e.g. towards OTel semantic-convention names like `k8s.namespace.name`/`k8s.deployment.name`).
- The 5-minute `lasting` window is there so a normal rolling update (which briefly dips available pods below desired) doesn't trigger a false alert. Tune it in `main.tf` if your rollouts are slower/faster.

## Detector: pods killed burst

`signalfx_detector.pods_killed_burst` fires when more than 5 pods are killed by the KubeInvaders chaos game within a rolling 1-minute window — useful as a guardrail against the game's auto-pilot or a misconfigured `alienProximity`/`hitsLimit` deleting pods faster than the cluster can reschedule them.

This one reads `deleted_pods_total` — the same counter as the `killed_pods_total` panel on the dashboard — so it needs the app's own `/metrics` scrape (`otelSidecar.enabled=true`), not the cluster-wide collector.
