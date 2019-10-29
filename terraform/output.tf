output "vpc_vsi_bastion_fip" {
  value = "${module.vpc_bastion.vpc_vsi_bastion_fip}"
}

output "vpc_vsi_1_ip" {
  value = "${var.vpc_zone_count > 0 ? element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, 0) : ""}"
}

output "vpc_vsi_2_ip" {
  value = "${var.vpc_zone_count > 1 ? element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, 1) : ""}"
}

output "vpc_vsi_3_ip" {
  value = "${var.vpc_zone_count > 2 ? element(ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address, 2) : ""}"
}

output "lb_public_hostname" {
  value = "${ibm_is_lb.lb_public.hostname}"
}

output "vpc_vsi_addresses" {
  value = "${ibm_is_instance.vsi_app.*.primary_network_interface.0.primary_ipv4_address}"
}

output "vpc_zone_count" {
  value = "${var.vpc_zone_count}"
}