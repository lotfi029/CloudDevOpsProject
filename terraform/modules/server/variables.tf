variable "project_name" {
  type    = string
  default = "clouddevops"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "ami_id" {
  description = "AMI ID for Jenkins EC2 (Ubuntu 22.04)"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}