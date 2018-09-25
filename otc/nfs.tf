resource "openstack_networking_floatingip_v2" "nfs-clients" {
  depends_on = ["openstack_compute_instance_v2.nfs-clients"]
  port_id  = "${element(openstack_networking_port_v2.nfs-clients.*.id, count.index)}"
  count = "${var.client_count}"
  pool  = "${var.external_network}"
}

resource "openstack_compute_instance_v2" "nfs-clients" {
  count           = "${var.nfs_client_count}"
  name            = "${var.project}-nfs-client-${format("%02d", count.index+1)}"
  # image_name      = "${var.image_name}"				#"bitnami-ceph-osdstack-7.0.22-1-linux-centos-7-x86_64-mp"
  flavor_name     = "${var.nfs_client_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone2}"
  security_groups = [
    "${openstack_compute_secgroup_v2.ceph.name}"
  ]
  network {
    port = "${element(openstack_networking_port_v2.nfs-clients.*.id, count.index)}"
    access_network = true
  }
  block_device {
    uuid                  = "${element(openstack_blockstorage_volume_v2.nfs-client-image-vols.*.id, count.index)}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "nfs-client-image-vols" {
  count           = "${var.nfs_client_count}"
  name = "${var.project}-${format("nfs-vol-%03d", count.index + 1)}"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone2}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "nfs-clients" {
  count              = "${var.nfs_client_count}"
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

resource "null_resource" "op-posix-nfs" { 
  depends_on = ["null_resource.op-posix-onedatify"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", openstack_compute_instance_v2.nfs-clients.*.name, openstack_compute_instance_v2.nfs-clients.*.access_ip_v4))}\n[server]\nlocalhost\n\n[clients]\n${join("\n", openstack_compute_instance_v2.nfs-clients.*.name)}\n"
    destination = "inventory-nfs.ini"
  }
  provisioner "remote-exec" {
    inline = [
      "grep ansible_host inventory-nfs.ini | cut -f2 -d= | xargs -I{} ssh -o StrictHostKeyChecking=no {} hostname",
      "ansible-playbook playbooks/nfs.yml -i inventory-nfs.ini --extra-vars \" nfs_clients_ips=${join(",", formatlist("%s", openstack_compute_instance_v2.nfs-clients.*.access_ip_v4))} nfs_server_ip=${openstack_compute_instance_v2.op-posix.access_ip_v4}\"",
    ]
  }
}

resource "null_resource" "nfs-client-desy-multi" { 
  depends_on = ["null_resource.prepare-op-posix","null_resource.op-posix-onedatify","null_resource.oneclients","null_resource.op-posix-nfs"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy-multi.yml -i inventory-nfs.ini --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} destination_provider=${openstack_compute_instance_v2.op-posix.name}.${var.onezone} ip_list=\\\"${join(" ", formatlist("%s", openstack_compute_instance_v2.client-nodes.*.access_ip_v4))}\\\"\"",
    ]
  }
}

resource "null_resource" "nfs-client-collectd" {
  depends_on = ["null_resource.provision-grafana","null_resource.op-posix-nfs"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i inventory-nfs.ini --extra-vars \" grafana_ip=${openstack_compute_instance_v2.grafana.access_ip_v4} \"",
    ]
  }
}

output "NFS clients addresses" {
  value = "${openstack_compute_instance_v2.nfs-clients.*.access_ip_v4}"
}

