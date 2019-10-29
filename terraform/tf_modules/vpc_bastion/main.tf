resource ibm_is_security_group "sg_bastion" {
  name = "${var.vpc_vsi_security_group_name}"
  vpc  = "${var.vpc_id}"
  resource_group = "${var.vpc_resource_group_id}"
}

resource "ibm_is_security_group_rule" "sg_bastion_inbound_tcp_22" {
  group     = "${ibm_is_security_group.sg_bastion.id}"
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp = {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "sg_bastion_outbound_tcp_22" {
  group     = "${ibm_is_security_group.sg_bastion.id}"
  direction = "outbound"
  remote    = "${ibm_is_security_group.sg_bastion.id}"

  tcp = {
    port_min = 22
    port_max = 22
  }
}

resource ibm_is_security_group "sg_maintenance" {
  name = "${var.vpc_maintenance_security_group_name}"
  vpc  = "${var.vpc_id}"
  resource_group = "${var.vpc_resource_group_id}"
}

resource "ibm_is_security_group_rule" "sg_maintenance_inbound_tcp_22" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "inbound"
  remote    = "${ibm_is_security_group.sg_bastion.id}"

  tcp = {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "sg_maintenance_outbound_iaas_endpoints" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "outbound"
  remote    = "161.26.0.0/16"
}

resource "ibm_is_security_group_rule" "sg_maintenance_outbound_tcp_53" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp = {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "sg_maintenance_outbound_udp_53" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "outbound"
  remote    = "0.0.0.0/0"

  udp = {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "sg_maintenance_outbound_tcp_443" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp = {
    port_min = 9443
    port_max = 9443
  }
}

resource "ibm_is_security_group_rule" "sg_maintenance_outbound_tcp_80" {
  group     = "${ibm_is_security_group.sg_maintenance.id}"
  direction = "outbound"
  remote    = "0.0.0.0/0"

  tcp = {
    port_min = 9080
    port_max = 9080
  }
}

data ibm_is_ssh_key "ssh_key" {
  count = "${length(var.vpc_ssh_keys)}"
  name  = "${var.vpc_ssh_keys[count.index]}"
}

resource ibm_is_subnet "sub_bastion" {
  count                    = "1"
  name                     = "${var.vpc_subnet_name}"
  vpc                      = "${var.vpc_id}"
  zone                     = "${lookup(var.vpc_zones, "${var.vpc_region}-availability-zone-${count.index + 1}")}"
  total_ipv4_address_count = 16
  public_gateway           = "${var.vpc_public_gateway_id}"
}

data ibm_is_image "image_name" {
  name = "${var.vpc_vsi_image_name}"
}

resource ibm_is_instance "vpc_vsi_bastion" {
  count          = 1
  name           = "${var.vpc_vsi_name}"
  vpc            = "${var.vpc_id}"
  zone           = "${lookup(var.vpc_zones, "${var.vpc_region}-availability-zone-${count.index + 1}")}"
  keys           = ["${data.ibm_is_ssh_key.ssh_key.*.id}"]
  image          = "${data.ibm_is_image.image_name.id}"
  profile        = "${var.vpc_vsi_image_profile}"
  resource_group = "${var.vpc_resource_group_id}"

  primary_network_interface = {
    subnet          = "${element(ibm_is_subnet.sub_bastion.*.id, count.index)}"
    security_groups = ["${ibm_is_security_group.sg_bastion.id}", "${ibm_is_security_group.sg_maintenance.id}"]
  }
}

resource ibm_is_floating_ip "vpc_vsi_bastion_fip" {
  count  = 1
  name   = "${var.vpc_vsi_fip_name}"
  target = "${ibm_is_instance.vpc_vsi_bastion.primary_network_interface.0.id}"
}
