resource "openstack_networking_network_v2" "my_network" {
  name = "network-waage"
}

resource "openstack_networking_subnet_v2" "my_subnet" {
  name        = "${openstack_networking_network_v2.my_network.name}-subnet"
  network_id  = openstack_networking_network_v2.my_network.id
  cidr        = "192.168.1.0/24"
  ip_version  = 4
  enable_dhcp = true

}

resource "openstack_networking_secgroup_v2" "my_secgroup" {
  name        = "my_secgroup"
  description = "Security group for SSH access"
}

resource "openstack_networking_secgroup_rule_v2" "ingress_grafana" {
  security_group_id = openstack_networking_secgroup_v2.my_secgroup.id
  ethertype         = "IPv4"
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "${var.internal_network_gateway}/32"
}

resource "openstack_networking_secgroup_rule_v2" "ingress_frontend" {
  security_group_id = openstack_networking_secgroup_v2.my_secgroup.id
  ethertype         = "IPv4"
  direction         = "ingress"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "outgoing" {
  security_group_id = openstack_networking_secgroup_v2.my_secgroup.id
  ethertype         = "IPv4"
  direction         = "egress"
  protocol          = "tcp"
  port_range_min    = 1883
  port_range_max    = 1883
  remote_ip_prefix  = "0.0.0.0/0"
}


resource "openstack_compute_instance_v2" "server" {
  name              = "server"
  image_name        = "ubuntu-24.04-x86_64"
  flavor_name       = "c5.tiny"
  availability_zone = "az1"
  security_groups   = [openstack_networking_secgroup_v2.my_secgroup.name]

  user_data = templatefile("setup.sh", {
    DB_PATH = "/data/bierwaage.duckdb"
  })


  network {
    uuid = openstack_networking_network_v2.my_network.id
  }

}

resource "openstack_networking_floatingip_v2" "public_ip" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.public_ip.address
  instance_id = openstack_compute_instance_v2.server.id
}

resource "openstack_compute_volume_attach_v2" "attach_volume" {
  instance_id = openstack_compute_instance_v2.server.id
  volume_id   = openstack_blockstorage_volume_v3.my_persistent_volume.id
  device      = "/dev/sdb"

}

resource "openstack_blockstorage_volume_v3" "my_persistent_volume" {
  name = "waage_volume"
  size = 3
}

resource "openstack_networking_router_v2" "my_router" {
  name                = "waage_router"
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = openstack_networking_router_v2.my_router.id
  subnet_id = openstack_networking_subnet_v2.my_subnet.id
}
