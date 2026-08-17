# Sending K8s/container logs to Splunk Platform (Log Observer Connect)

Log Observer Connect (LOC) is already linked on the Splunk Observability
Cloud side for this org. What's still missing is the actual log pipeline:
container/K8s logs need to be shipped from this cluster into the Splunk
Enterprise/Cloud instance that LOC reads from, via HTTP Event Collector
(HEC).

The existing `splunk-otel-collector` release (namespace `default`) already
tails every container's logs by default
(`logsCollection.containers.enabled: true`) - it's just not routed
anywhere yet. Adding a `splunkPlatform` destination is all that's needed;
metrics and traces keep going to Splunk Observability Cloud unchanged.

## What to request from whoever manages the Splunk Platform instance

1. **HEC endpoint URL.**
   - Self-managed Splunk Enterprise: `https://<host>:8088/services/collector`
   - Splunk Cloud: `https://http-inputs-<your-stack>.splunkcloud.com:443/services/collector`
2. **A HEC token**, ideally created specifically for this K8s log source
   (Settings → Data Inputs → HTTP Event Collector → New Token), with write
   access to the index below.
3. **The index name that Log Observer Connect is actually scoped to read.**
   This has to match, or LOC won't surface the logs even if they're
   ingested successfully. If unsure, check the LOC configuration in
   Splunk O11y (Settings → Log Observer Connect) for which index/indexes
   it's reading from, or ask the Splunk admin which index was granted for
   this purpose.
4. **A sourcetype**, if there's an existing convention to follow (otherwise
   the collector's defaults are fine to start with).

## Applying it once you have those

1. Copy `splunk-platform-logs-values.yaml` to `splunk-platform-logs-values.local.yaml`
   (gitignored - the real token must never be committed) and fill in the
   three `REPLACE_ME_*` placeholders.
2. Apply on top of the existing release:

   ```bash
   helm upgrade splunk-otel-collector signalfx/splunk-otel-collector \
     -n default \
     -f <whatever values file(s) the existing release was installed with> \
     -f confs/splunk-o11y/splunk-platform-logs-values.local.yaml
   ```

3. Verify logs are arriving directly in Splunk Platform first (Splunk Web
   search: `index=<your index>` over the last few minutes) before checking
   Log Observer Connect in Splunk O11y - that isolates whether a problem
   is in the pipeline or in the LOC linking itself.
