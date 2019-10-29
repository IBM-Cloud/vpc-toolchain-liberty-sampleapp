output "vpc_vsi_bastion_fip" {
  value = "${ibm_is_floating_ip.vpc_vsi_bastion_fip.0.address}"
}

output sg_maintenance_id {
  value = "${ibm_is_security_group.sg_maintenance.id}"
}

output sg_bastion_id {
  value = "${ibm_is_security_group.sg_bastion.id}"
}

output "bastion_subnet_cidr_block" {
  value = "${ibm_is_subnet.sub_bastion.ipv4_cidr_block}"
}
