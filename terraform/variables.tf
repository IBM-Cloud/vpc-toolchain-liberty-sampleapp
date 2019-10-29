variable "ibmcloud_api_key" {}

variable "vpc_region" {
  description = "Region to deploy."
}

variable "vpc_ssh_keys" {
  description = "ssh keys used to access virtual server instances after creation."
  default = []
}

variable "vpc_resource_group" {
  description = "resource group for the resources created."
}

variable "ssh_private_key" {
  description = "location of private ssh key for virtual server instances access."
  default     = "~/.ssh/id_rsa"
}

variable "vpc_resources_prefix" {
  description = "value prefixed to all resources created."
}

variable "generation" {
  default = 1
}

variable "vpc_zones" {
  default = {
    au-syd-availability-zone-1   = "au-syd-1"
    au-syd-availability-zone-2   = "au-syd-2"
    au-syd-availability-zone-3   = "au-syd-3"
    eu-de-availability-zone-1    = "eu-de-1"
    eu-de-availability-zone-2    = "eu-de-2"
    eu-de-availability-zone-3    = "eu-de-3"
    eu-gb-availability-zone-1    = "eu-gb-1"
    eu-gb-availability-zone-2    = "eu-gb-2"
    eu-gb-availability-zone-3    = "eu-gb-3"
    jp-tok-availability-zone-1   = "jp-tok-1"
    jp-tok-availability-zone-2   = "jp-tok-2"
    jp-tok-availability-zone-3   = "jp-tok-3"
    us-south-availability-zone-1 = "us-south-1"
    us-south-availability-zone-2 = "us-south-2"
    us-south-availability-zone-3 = "us-south-3"
  }
}

variable "vpc_image_profile" {
  default = "cc1-2x4"
}

variable "vpc_image_name" {
  default = "ubuntu-18.04-amd64"
}

variable "vpc_zone_count" {
  default = 1
}
