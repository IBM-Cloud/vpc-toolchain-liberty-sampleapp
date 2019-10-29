terraform {
  # required_version = "0.11.8"
  # required_version = "0.11.14"
}

provider "ibm" {
  ibmcloud_api_key = "${var.ibmcloud_api_key}"
  ibmcloud_timeout = 300
  generation       = "${var.generation}"
  region           = "${var.vpc_region}"
}

provider "null" {
  version = "~> 2.1"
}

data "ibm_resource_group" "group" {
  name = "${var.vpc_resource_group}"
}

resource ibm_is_vpc "vpc" {
  name           = "${var.vpc_resources_prefix}-vpc"
  resource_group = "${data.ibm_resource_group.group.id}"
}

data ibm_is_image "image_name" {
  name = "${var.vpc_image_name}"
}

data ibm_is_ssh_key "ssh_key" {
  count = "${length(var.vpc_ssh_keys)}"
  name  = "${var.vpc_ssh_keys[count.index]}"
}

resource "ibm_is_public_gateway" "pgw" {
  count = "${var.vpc_zone_count}"
  name  = "${var.vpc_resources_prefix}-pgw-${count.index + 1}"
  vpc   = "${ibm_is_vpc.vpc.id}"
  zone  = "${lookup(var.vpc_zones, "${var.vpc_region}-availability-zone-${count.index + 1}")}"
}

module "vpc_bastion" {
  source = "./tf_modules/vpc_bastion"

  vpc_id                = "${ibm_is_vpc.vpc.id}"
  vpc_resource_group_id = "${data.ibm_resource_group.group.id}"
  vpc_public_gateway_id = "${ibm_is_public_gateway.pgw.0.id}"

  vpc_ssh_keys          = "${var.vpc_ssh_keys}"
  vpc_region            = "${var.vpc_region}"
  vpc_zones             = "${var.vpc_zones}"
  vpc_vsi_image_profile = "${var.vpc_image_profile}"
  vpc_vsi_image_name    = "${var.vpc_image_name}"

  vpc_vsi_name                        = "${var.vpc_resources_prefix}-vsi-admin"
  vpc_vsi_security_group_name         = "${var.vpc_resources_prefix}-sg-admin"
  vpc_subnet_name                     = "${var.vpc_resources_prefix}-sub-admin-1"
  vpc_vsi_fip_name                    = "${var.vpc_resources_prefix}-vsi-admin-fip"
  vpc_maintenance_security_group_name = "${var.vpc_resources_prefix}-sg-maintenance"
}

resource ibm_is_subnet "sub_app" {
  count                    = "${var.vpc_zone_count}"
  name                     = "${var.vpc_resources_prefix}-sub-app-${count.index + 1}"
  vpc                      = "${ibm_is_vpc.vpc.id}"
  zone                     = "${lookup(var.vpc_zones, "${var.vpc_region}-availability-zone-${count.index + 1}")}"
  total_ipv4_address_count = 16
  public_gateway           = "${element(ibm_is_public_gateway.pgw.*.id, count.index)}"
}

resource ibm_is_security_group "sg_app" {
  name = "${var.vpc_resources_prefix}-sg-app"
  vpc  = "${ibm_is_vpc.vpc.id}"
  resource_group = "${data.ibm_resource_group.group.id}"
}

resource "ibm_is_security_group_rule" "sg_app_inbound_tcp_9080" {
  group     = "${ibm_is_security_group.sg_app.id}"
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp = {
    port_min = 9080
    port_max = 9080
  }
}

# resource "ibm_is_security_group_rule" "sg_app_inbound_tcp_9043" {
#   group     = "${ibm_is_security_group.sg_app.id}"
#   direction = "inbound"
#   remote    = "0.0.0.0/0"

#   tcp = {
#     port_min = 9043
#     port_max = 9043
#   }
# }

resource ibm_is_instance "vsi_app" {
  count          = "${var.vpc_zone_count}"
  name           = "${var.vpc_resources_prefix}-vsi-app-${count.index + 1}"
  vpc            = "${ibm_is_vpc.vpc.id}"
  zone           = "${lookup(var.vpc_zones, "${var.vpc_region}-availability-zone-${count.index + 1}")}"
  keys           = ["${data.ibm_is_ssh_key.ssh_key.*.id}"]
  image          = "${data.ibm_is_image.image_name.id}"
  profile        = "${var.vpc_image_profile}"
  resource_group = "${data.ibm_resource_group.group.id}"

  primary_network_interface = {
    subnet          = "${element(ibm_is_subnet.sub_app.*.id, count.index)}"
    security_groups = ["${module.vpc_bastion.sg_bastion_id}", "${ibm_is_security_group.sg_app.id}", "${module.vpc_bastion.sg_maintenance_id}"]
  }
}

resource "ibm_is_lb" "lb_public" {
  name           = "${var.vpc_resources_prefix}-lb-public"
  type           = "public"
  subnets        = ["${ibm_is_subnet.sub_app.*.id}"]
  resource_group = "${data.ibm_resource_group.group.id}"
}

resource "ibm_is_lb_pool" "app_pool" {
  name               = "app"
  lb                 = "${ibm_is_lb.lb_public.id}"
  algorithm          = "round_robin"
  protocol           = "http"
  health_delay       = 60
  health_retries     = 5
  health_timeout     = 2
  health_type        = "http"
  health_monitor_url = "/health"
}

resource "ibm_is_lb_listener" "app_listener" {
  lb           = "${ibm_is_lb.lb_public.id}"
  default_pool = "${element(split("/",ibm_is_lb_pool.app_pool.id),1)}"
  port         = 80
  protocol     = "http"
}

resource "ibm_is_lb_pool_member" "app_pool_members_9080" {
  count          = "${var.vpc_zone_count}"
  lb             = "${ibm_is_lb.lb_public.id}"
  pool           = "${element(split("/",ibm_is_lb_pool.app_pool.id),1)}"
  port           = 9080
  target_address = "${element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
}

# resource "ibm_is_lb_pool_member" "app_pool_members_9043" {
#   count          = "${var.vpc_zone_count}"
#   lb             = "${ibm_is_lb.lb_public.id}"
#   pool           = "${element(split("/",ibm_is_lb_pool.app_pool.id),1)}"
#   port           = 9043
#   target_address = "${element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
# }

resource "null_resource" "vsi_app" {
  count = "${var.vpc_zone_count}"

  connection {
    type         = "ssh"
    host         = "${element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, count.index)}"
    user         = "root"
    private_key  = "${file("${var.ssh_private_key}")}"
    bastion_host = "${module.vpc_bastion.vpc_vsi_bastion_fip}"
    timeout      = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y openjdk-8-jre unzip",
      "echo \"HOSTNAME=$(cat /etc/hostname)\" >> /etc/environment"
    ]
  }
}
