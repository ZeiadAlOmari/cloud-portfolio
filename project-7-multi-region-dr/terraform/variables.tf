variable "simulate_primary_outage" {
  description = "When true, the primary bucket refuses CloudFront reads, so CloudFront sees the primary origin failing and fails over to the secondary region"
  type        = bool
  default     = false
}
