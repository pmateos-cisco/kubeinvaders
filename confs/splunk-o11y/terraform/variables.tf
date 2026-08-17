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
