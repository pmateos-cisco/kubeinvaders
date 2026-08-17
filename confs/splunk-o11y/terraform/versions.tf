terraform {
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = ">= 9.0.0"
    }
  }
}

provider "signalfx" {
  auth_token = var.splunk_api_token
  api_url    = "https://api.${var.splunk_realm}.observability.splunkcloud.com"
}
