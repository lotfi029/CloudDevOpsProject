variable "project_name" {
  type    = string
  default = "clouddevops"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "k8s_version" {
  type    = string
  default = "1.32"
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"
}