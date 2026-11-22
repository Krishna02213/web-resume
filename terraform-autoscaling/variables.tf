variable "instance_type" {
  description = "EC2 instance size"
  type        = string
}

variable "ssh_cidr" {
  description = "Your public IP address allowed to connect through SSH"
  type        = string
}

variable "min_servers" {
  description = "Minimum number of running website servers"
  type        = number
  default     = 1
}

variable "max_servers" {
  description = "Maximum number of running website servers"
  type        = number
  default     = 3
}

variable "requests_per_server" {
  description = "Target average requests per server in a one-minute interval"
  type        = number
  default     = 100
}

variable "cpu_target_percent" {
  description = "Target average CPU utilization across website servers"
  type        = number
  default     = 50
}
