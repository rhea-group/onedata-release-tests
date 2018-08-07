resource "openstack_networking_floatingip_v2" "grafana" {
  depends_on = ["openstack_compute_instance_v2.grafana"]
  port_id  = "${openstack_networking_port_v2.grafana-port.id}"
  # count = "${var.provider_count}"
  pool  = "${var.external_network}"
}


resource "openstack_compute_instance_v2" "grafana" {
  depends_on = ["openstack_networking_router_interface_v2.interface"]
  name            = "${var.project}-grafana"
  # image_name      = "${var.image_name}"
  flavor_name     = "${var.grafana_flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"

  network {
    port = "${openstack_networking_port_v2.grafana-port.id}"
    uuid = "${openstack_networking_network_v2.network.id}"
    access_network = true
  }
    block_device {
    uuid                  = "${openstack_blockstorage_volume_v2.grafana-image-vol.id}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "grafana-image-vol" {
  name = "${var.project}-op-vol"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "grafana-port" {
  network_id         = "${openstack_networking_network_v2.network.id}"
  security_group_ids = [
    "${openstack_compute_secgroup_v2.op.id}",
    "${openstack_compute_secgroup_v2.ceph.id}",
  ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
}


# resource "exoscale_compute" "grafana" {
#   # depends_on = ["exoscale_affinity.op"]
#   display_name =  "${var.project}-grafana"
#   template = "Linux CentOS 7.4 64-bit"
#   zone = "${var.zone}"
#   size = "${var.grafana_flavor_name}"
#   disk_size = 100
#   key_pair = "${var.project}-exo"
#   security_groups = ["${exoscale_security_group.ceph.name}","${exoscale_security_group.op.name}"]
# }

resource "null_resource" "provision-grafana" {
  depends_on = [ "openstack_compute_instance_v2.grafana", "null_resource.prepare-op-ceph"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "180s"
  }
  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -R ${openstack_networking_floatingip_v2.grafana.address}",
      "ssh -o StrictHostKeyChecking=no ${openstack_networking_floatingip_v2.grafana.address} date",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i \"${openstack_networking_floatingip_v2.grafana.address},\" playbooks/grafana.yml",
    ]
  }
}

output "Grafana IP address" {
  value = "${openstack_networking_floatingip_v2.grafana.address}"
}

