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
  name       = "Chaos jobs"
  program_text = "A = data('chaos_jobs_node_count', rollup='delta').sum(by=['node']).publish(label='A')"
  plot_type  = "LineChart"
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
  name       = "Killed pods"
  program_text = "A = data('deleted_namespace_pods_count', rollup='delta').sum(by=['namespace']).publish(label='A')"
  plot_type  = "LineChart"
}

resource "signalfx_list_chart" "chaos_jobs_count" {
  name         = "Chaos jobs count"
  program_text = "A = data('chaos_jobs_node_count').publish(label='A')"
}

resource "signalfx_list_chart" "killed_pods_count" {
  name         = "Killed pods count"
  program_text = "A = data('deleted_namespace_pods_count').sum(by=['namespace']).publish(label='A')"
}

resource "signalfx_dashboard" "kubeinvaders" {
  name            = "KubeInvaders Dashboard"
  dashboard_group = signalfx_dashboard_group.kubeinvaders.id

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
}
