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
