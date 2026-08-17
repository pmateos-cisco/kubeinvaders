variable "splunk_api_token" {
  description = "Splunk Observability Cloud API token with dashboard/chart write access (an org or user API token - NOT the ingest-only access token used by the otel collector)."
  type        = string
  sensitive   = true
}

variable "splunk_realm" {
  description = "Splunk Observability Cloud realm, e.g. us1."
  type        = string
  default     = "us1"
}

variable "detector_notifications" {
  description = "Notification targets for the deployment-availability detector, e.g. [\"Email,me@example.com\"] or [\"Slack,<channel_id>,<credential_id>\"]. See the signalfx_detector docs for the full recipient syntax. Left empty by default so the detector is created without alerting anyone."
  type        = list(string)
  default     = []
}
