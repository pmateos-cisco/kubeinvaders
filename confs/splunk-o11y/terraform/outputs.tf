output "dashboard_url" {
  value = signalfx_dashboard.kubeinvaders.url
}

output "deployment_availability_detector_url" {
  value = signalfx_detector.deployment_available_below_desired.url
}

output "pods_killed_burst_detector_url" {
  value = signalfx_detector.pods_killed_burst.url
}
