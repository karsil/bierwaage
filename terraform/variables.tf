variable "external_network_id" {
  description = "ID of the external OpenStack network used for the router and floating IPs"
  type        = string
}

variable "floating_ip_address" {
  description = "Address of the existing floating IP to associate with the server"
  type        = string
}

variable "internal_network_gateway" {
  description = "IP of the internal network gateway"
  type        = string
}
