resource "openstack_networking_floatingip_v2" "client-nodes" {
  depends_on = ["openstack_compute_instance_v2.client-nodes"]
  port_id  = "${element(openstack_networking_port_v2.client-ports.*.id, count.index)}"
  count = "${var.client_count}"
  pool  = "${var.external_network}"
}

resource "openstack_compute_instance_v2" "client-nodes" {
  count           = "${var.client_count}"
  name            = "${var.project}-client-node-${format("%02d", count.index+1)}"
  # image_name      = "${var.image_name}"				#"bitnami-ceph-osdstack-7.0.22-1-linux-centos-7-x86_64-mp"
  flavor_name     = "${var.ceph_node_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"
  security_groups = [
    "${openstack_compute_secgroup_v2.ceph.name}"
  ]
  network {
    port = "${element(openstack_networking_port_v2.client-ports.*.id, count.index)}"
    access_network = true
  }
  block_device {
    uuid                  = "${element(openstack_blockstorage_volume_v2.client-image-vols.*.id, count.index)}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "client-image-vols" {
  count           = "${var.client_count}"
  name = "${var.project}-${format("vol-%03d", count.index + 1)}"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "client-ports" {
  count              = "${var.client_count}"
  network_id         = "${openstack_networking_subnet_v2.subnet.network_id}"
  no_security_groups = "false"
  # security_group_ids = [
  #   "${openstack_compute_secgroup_v2.secgrp_ceph.id}",
  # ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
}

resource "null_resource" "oneclients" {
#  count = "${var.client_count}"
  depends_on = ["null_resource.op-ceph-onedatify"]
  connection {
    # host = "${element(openstack_networking_floatingip_v2.client-nodes.*.address, count.index)}"
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", openstack_compute_instance_v2.client-nodes.*.name, openstack_compute_instance_v2.client-nodes.*.access_ip_v4))}\n[clients]\n${join("\n", openstack_compute_instance_v2.client-nodes.*.name)}\n"
    destination = "inventory-clients.ini"
  }
  provisioner "remote-exec" {
    inline = [  
      "grep ansible_host inventory-clients.ini | cut -f2 -d= | xargs -I{} ssh -o StrictHostKeyChecking=no {} hostname",
      "ansible-playbook playbooks/oneclients.yml -i inventory-clients.ini --extra-vars \"oneprovider=${openstack_compute_instance_v2.op-ceph.name}.${var.onezone} access_token=${var.access_token} oneclient_package=${var.oneclient_package} grafana_ip=${openstack_networking_floatingip_v2.grafana.address}\"",
    ]
  }
}

variable "client_count" {
  default = "2"
}

output "Oneclients nodes addresses" {
  value = "${openstack_networking_floatingip_v2.client-nodes.*.address}"
}
