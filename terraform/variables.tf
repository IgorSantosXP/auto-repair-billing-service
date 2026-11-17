variable "project" {
  type    = string
  default = "auto-repair"
}

variable "service" {
  description = "Service name, also the value of the `destination` message attribute this queue receives"
  type        = string
  default     = "billing"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environments" {
  description = "Environment => Kubernetes namespace where the service runs"
  type        = map(string)
  default = {
    prod    = "auto-repair-billing-prod"
    homolog = "auto-repair-billing-homolog"
  }
}

variable "service_account" {
  description = "Kubernetes service account used by the api and worker pods"
  type        = string
  default     = "billing-service"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  type    = string
  default = "16"
}

variable "db_username" {
  type    = string
  default = "billing"
}
