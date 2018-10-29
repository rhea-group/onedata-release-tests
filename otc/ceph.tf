# data "openstack_networking_subnet_v2" "subnet" {
#   name = "${var.project}-subnet"
# }

# data "template_file" "mgt_ip" {
#   template = "$${mgt_ip}"
#   vars {
#     mgt_ip = "${openstack_networking_floatingip_v2.ceph-mgt.address}"
#   }
# }

# data "openstack_dns_zone_v2" "dnszone" {
#   name = "${var.dnszone}"
# }

# resource "openstack_dns_recordset_v2" "ceph-mons" {
#   depends_on = ["null_resource.provision-mgt"]
#   #count   = "${var.ceph-mon_count}"
#   zone_id = "${data.openstack_dns_zone_v2.dnszone.id}"
#   name    = "${var.project}-ceph-mon.${var.dnszone}."
#   type    = "A"
#   # records = ["${openstack_compute_instance_v2.ceph-mons.*.access_ip_v4}"]
#   records = ["${split("\n", trimspace(file("mon_ips")))}"]
# }

resource "openstack_networking_floatingip_v2" "ceph-nodes" {
  depends_on = ["openstack_compute_instance_v2.ceph-nodes"]
  port_id  = "${element(openstack_networking_port_v2.nodes-port.*.id, count.index)}"
  count = "${var.ceph-mon_count}"
  pool  = "${var.external_network}"
}

resource "openstack_compute_instance_v2" "ceph-nodes" {
  count           = "${var.ceph-node_count}"
  name            = "${var.project}-ceph-node-${format("%02d", count.index+1)}"
  # image_name      = "${var.image_name}"				#"bitnami-ceph-osdstack-7.0.22-1-linux-centos-7-x86_64-mp"
  flavor_name     = "${var.ceph_node_flavor}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"
  security_groups = [
    "${openstack_compute_secgroup_v2.ceph.name}"
  ]
  network {
    port = "${element(openstack_networking_port_v2.nodes-port.*.id, count.index)}"
    access_network = true
  }
  block_device {
    uuid                  = "${element(openstack_blockstorage_volume_v2.ceph-node-image-vols.*.id, count.index)}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "ceph-node-image-vols" {
  count           = "${var.ceph-node_count}"
  name = "${var.project}-${format("vol-%03d", count.index + 1)}"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "nodes-port" {
  count              = "${var.ceph-node_count}"
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

resource "null_resource" "ceph-node-connect" {
  count = "${var.ceph-node_count}"
  # depends_on = ["null_resource.prepare-op-ceph", "openstack_networking_floatingip_v2.ceph-nodes"]
  connection {
    bastion_host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    host     = "${element(openstack_compute_instance_v2.ceph-nodes.*.access_ip_v4, count.index)}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "echo Connected ....",
    ]
  }
}

resource "null_resource" "provision-ceph" {
  depends_on = ["null_resource.ceph-node-connect","openstack_compute_volume_attach_v2.vas","null_resource.prepare-op-ceph"]
  # triggers {
  #   cluster_instance_ids = "${join(",", openstack_networking_floatingip_v2.ceph-mgt.*.address)}"
  # }
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
  }
  provisioner "file" {
    content = "\n# Ceph nodes\n${join("\n", formatlist("%s %s", openstack_compute_instance_v2.ceph-nodes.*.access_ip_v4, openstack_compute_instance_v2.ceph-nodes.*.name))}\n"
    destination = "ceph-nodes.tmp"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", openstack_compute_instance_v2.ceph-nodes.*.name, openstack_compute_instance_v2.ceph-nodes.*.access_ip_v4))}\n[mgt]\nlocalhost\n\n[mons]\n${join("\n", slice(openstack_compute_instance_v2.ceph-nodes.*.name,0,var.ceph-mon_count))}\n\n[osds]\n${join("\n",formatlist("%s", openstack_compute_instance_v2.ceph-nodes.*.name))}"
    destination = "inventory-ceph.ini"
  }
  # provisioner "file" {
  #   source = "etc.tgz"
  #   destination = "etc.tgz"
  # }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/[0-9.]* .*-ceph-.*//' /etc/hosts",
      "sudo sh -c 'cat ceph-nodes.tmp >> /etc/hosts'",
      "cat /etc/hosts",
      "ping -c 1 ${openstack_compute_instance_v2.ceph-nodes.0.name}",
      "echo After ping",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "for i in ${join(" ",formatlist("%s",openstack_compute_instance_v2.ceph-nodes.*.name))}; do ssh-keygen -R $i; done",
      "for i in ${join(" ",formatlist("%s",openstack_compute_instance_v2.ceph-nodes.*.name))}; do ssh -o StrictHostKeyChecking=no $i date; done",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      # "tar zxvf playbooks.tgz",
      # "tar zxvf etc.tgz",
      # "sudo cp etc/ansible-hosts inventory-ceph.ini",
      # "sudo cp etc/ssh_config /etc/ssh/ssh_config",
#      "ansible-playbook -i inventory.ini playbooks/kube-ceph/kube-ceph-clean.yml -f 50 -T 30", 
#      "ansible-playbook -i inventory-ceph.ini playbooks/myceph/myceph-clean.yml -f 50 -T 30", 
      "ansible-playbook -i inventory-ceph.ini playbooks/myceph/ib-hosts-ceph.yml -f 50 -T 30", 
      "ansible-playbook playbooks/myceph/myceph.yml -i inventory-ceph.ini --extra-vars \"osd_disks=${var.disks-per-osd_count} vol_prefix=${var.vol_prefix} ramdisk_size=${var.ramdisk_size}\" -f 50 -T 30",
    ]
  }
}

resource "null_resource" "ceph-nodes-collectd" { 
  depends_on = ["null_resource.provision-grafana"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i inventory-ceph.ini --extra-vars \" grafana_ip=${openstack_networking_floatingip_v2.grafana.address} \"",
    ]
  }
}

resource "openstack_blockstorage_volume_v2" "vols" {
  count           = "${var.ceph-node_count * var.disks-per-osd_count}"
  name = "${var.project}-${format("vol-%03d", count.index + 1)}"
  size = "${var.vol_size}"
  volume_type = "${var.vol_type}"
  availability_zone = "${var.otc_availability_zone}"
}

resource "openstack_compute_volume_attach_v2" "vas" {
  count           = "${var.ceph-node_count * var.disks-per-osd_count}"
  instance_id = "${element(openstack_compute_instance_v2.ceph-nodes.*.id, count.index / var.disks-per-osd_count)}"
  volume_id   = "${element(openstack_blockstorage_volume_v2.vols.*.id, count.index)}"
}
