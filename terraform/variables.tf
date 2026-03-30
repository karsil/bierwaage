variable "external_network_id" {
  description = "ID of the external OpenStack network used for the router and floating IPs"
  type        = string
}

variable "floating_ip_pool" {
  description = "Name of the OpenStack floating IP pool"
  type        = string
}

variable "internal_network_gateway" {
  description = "IP of the internal network gateway"
  type        = string
}
