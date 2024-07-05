variable "project" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "your-project-id"
}

variable "service_account_email" {
  description = "The service account email"
  type        = string
  default     = "your-service-account@your-project-id.iam.gserviceaccount.com"
}

variable "credentials_file" {
  description = "Path to the Google Cloud credentials JSON file"
  type        = string
  default     = "/path/to/your/credentials.json"
}

variable "region" {
  description = "The Google Cloud region"
  type        = string
  default     = "your-region"
}

variable "zone" {
  description = "The Google Cloud zone"
  type        = string
  default     = "your-zone"
}

variable "username" {
  description = "The username for SSH access on cluster"
  type        = string
  default     = "your-username"
}

variable "machine_type" {
  description = "The machine type to use for instances"
  type        = string
  default     = "e2-small"
}

variable "image" {
  description = "The image to use for instances"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "pod_network_cidr" {
  description = "CIDR for the pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

