# Splunk Observability Cloud equivalent of confs/grafana/KubeInvadersDashboard.json
#
# Source metrics come from KubeInvaders' own /metrics Prometheus endpoint,
# scraped by the otel-sidecar (see helm-charts/kubeinvaders otelSidecar.*
# values) rather than a Prometheus server. Panel-by-panel mapping from the
# original Grafana PromQL to SignalFlow:
#
#   Grafana "Chaos jobs"                -> round(increase(chaos_jobs_node_count[5m])) by node
#   Grafana "Killed pods" (stat)        -> deleted_pods_total (instant)
#   Grafana "Chaos jobs against nodes"  -> chaos_node_jobs_total (instant)
#   Grafana "Killed pods" (graph)       -> sum by (namespace) (increase(deleted_namespace_pods_count[5m]))
#   Grafana "Chaos jobs count"          -> chaos_jobs_node_count (instant, by node)
#   Grafana "Killed pods count"         -> sum by (namespace) (deleted_namespace_pods_count)
#
# SignalFlow's rollup='delta' on a cumulative counter is the equivalent of
# Prometheus's increase() over the chart's resolution window.

resource "signalfx_dashboard_group" "kubeinvaders" {
  name        = "KubeInvaders"
  description = "Chaos engineering metrics for the KubeInvaders game"
}

resource "signalfx_time_chart" "chaos_jobs" {
  name         = "Chaos jobs"
  program_text = "A = data('chaos_jobs_node_count', rollup='delta').sum(by=['node']).publish(label='A')"
  plot_type    = "LineChart"
}

resource "signalfx_single_value_chart" "killed_pods_total" {
  name         = "Killed pods"
  program_text = "A = data('deleted_pods_total').publish(label='A')"
}

resource "signalfx_single_value_chart" "chaos_jobs_against_nodes" {
  name         = "Chaos jobs against nodes"
  program_text = "A = data('chaos_node_jobs_total').publish(label='A')"
}

resource "signalfx_time_chart" "killed_pods_by_namespace" {
  name         = "Killed pods"
  program_text = "A = data('deleted_namespace_pods_count', rollup='delta').sum(by=['namespace']).publish(label='A')"
  plot_type    = "LineChart"
}

resource "signalfx_list_chart" "chaos_jobs_count" {
  name                    = "Chaos jobs count"
  program_text            = "A = data('chaos_jobs_node_count').publish(label='A')"
  time_range              = 900
  secondary_visualization = "Sparkline"

  viz_options {
    label        = "A"
    display_name = "A"
  }
}

resource "signalfx_list_chart" "killed_pods_count" {
  name                    = "Killed pods count"
  program_text            = "A = data('deleted_namespace_pods_count').sum(by=['namespace']).publish(label='A')"
  time_range              = 900
  secondary_visualization = "Sparkline"

  viz_options {
    label        = "A"
    display_name = "A"
    color        = "orange"
  }
}

# Detector: alerts when any deployment in the cluster has fewer available
# pods than its desired replica count, regardless of namespace. Source
# metrics come from the cluster-wide OTel Collector's k8s_cluster receiver
# (kubernetes.deployment.*), not the app's own /metrics sidecar used by the
# panels above.
resource "signalfx_detector" "deployment_available_below_desired" {
  name        = "PMateos - KubeInvaders - available pods below desired"
  description = "A deployment's available pod count has stayed below its desired replica count for 5 minutes straight (e.g. CrashLoopBackOff, failed rollout, insufficient node resources to schedule). Cluster-wide, not scoped to a single namespace or deployment."

  program_text = <<-EOF
    available = data('kubernetes.deployment.available').publish(label='available', enable=False)
    desired = data('kubernetes.deployment.desired').publish(label='desired', enable=False)
    detect(when(available < desired, lasting='5m')).publish('Available pods below desired')
  EOF

  rule {
    description   = "available < desired for 5m"
    severity      = "Warning"
    detect_label  = "Available pods below desired"
    notifications = var.detector_notifications
  }
}

# Detector: alerts on a burst of chaos kills - more than 5 pods deleted by
# the KubeInvaders game within a rolling 1-minute window. Reads the app's
# own deleted_pods_total counter (same source as the killed_pods_total panel
# above), not the cluster-wide collector.
resource "signalfx_detector" "pods_killed_burst" {
  name        = "PMateos - KubeInvaders - pods killed burst"
  description = "More than 5 pods have been killed by the KubeInvaders chaos game within a 1 minute window."

  program_text = <<-EOF
    killed = data('deleted_pods_total', rollup='delta').sum(over='1m').publish(label='killed', enable=False)
    detect(when(killed > 5)).publish('Pods killed burst')
  EOF

  rule {
    description   = "more than 5 pods killed in 1m"
    severity      = "Warning"
    detect_label  = "Pods killed burst"
    notifications = var.detector_notifications
  }
}

# Log Observer Connect panel - see confs/splunk-o11y/log-observer-connect.md.
# Not producing data yet until that setup is finished; the query itself is
# correct and will start returning results once logs are flowing.
resource "signalfx_log_timeline" "kubeinvaders_logs" {
  name               = "Logs"
  program_text       = "logs(index='main', filter=field('k8s.cluster.name') == 'multi-node-cluster').count().publish()"
  default_connection = "LOC_pmateos"
  time_range         = 900
}

resource "signalfx_dashboard" "kubeinvaders" {
  name            = "PMateos - KubeInvaders Dashboard"
  dashboard_group = signalfx_dashboard_group.kubeinvaders.id
  time_range      = "-1h"

  filter {
    property       = "app"
    values         = ["kubeinvaders"]
    negated        = false
    apply_if_exist = false
  }

  chart {
    chart_id = signalfx_time_chart.chaos_jobs.id
    row      = 0
    column   = 0
    width    = 9
    height   = 2
  }

  chart {
    chart_id = signalfx_single_value_chart.killed_pods_total.id
    row      = 0
    column   = 9
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_single_value_chart.chaos_jobs_against_nodes.id
    row      = 1
    column   = 9
    width    = 3
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.killed_pods_by_namespace.id
    row      = 2
    column   = 0
    width    = 9
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.chaos_jobs_count.id
    row      = 4
    column   = 0
    width    = 10
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.killed_pods_count.id
    row      = 6
    column   = 0
    width    = 10
    height   = 2
  }

  chart {
    chart_id = signalfx_log_timeline.kubeinvaders_logs.id
    row      = 8
    column   = 0
    width    = 6
    height   = 1
  }
}
