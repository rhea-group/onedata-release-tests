resource "openstack_networking_floatingip_v2" "op-posix" {
  depends_on = ["openstack_compute_instance_v2.op-posix"]
  port_id  = "${openstack_networking_port_v2.op-posix-port.id}"
  # count = "${var.provider_count}"
  pool  = "${var.external_network}"
}


resource "openstack_compute_instance_v2" "op-posix" {
  depends_on = ["openstack_networking_router_interface_v2.interface"]
  name            = "${var.project}-otc-op2"
  # image_name      = "${var.image_name}"
  flavor_name     = "${var.op-posix_flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone2}"

  network {
    port = "${openstack_networking_port_v2.op-posix-port.id}"
#    uuid = "${openstack_networking_network_v2.network.id}"
    access_network = true
  }
    block_device {
    uuid                  = "${openstack_blockstorage_volume_v2.op-posix-image-vol.id}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "op-posix-image-vol" {
  name = "${var.project}-op-vol"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "op-posix-port" {
  network_id         = "${openstack_networking_subnet_v2.subnet.network_id}"
#  network_id         = "${openstack_networking_network_v2.network.id}"
  security_group_ids = [
    "${openstack_compute_secgroup_v2.op.id}",
  ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
}

resource "openstack_blockstorage_volume_v2" "op-posix-vol" {
  name = "${var.project}-op-posix-vol"
  size = "${var.op-posix-vol_size}"
  volume_type = "${var.vol_type}"
  availability_zone = "${var.otc_availability_zone}"
}

resource "openstack_compute_volume_attach_v2" "op-posix-vas" {
  instance_id = "${openstack_compute_instance_v2.op-posix.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.op-posix-vol.id}"
}

resource "null_resource" "prepare-op-posix" {
  depends_on = ["null_resource.local-setup"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
  }
  provisioner "file" {
    source = "../playbooks.tgz"
    destination = "playbooks.tgz"
  }
  provisioner "remote-exec" {
    inline = [
      # "sudo sed -i 's/[0-9.]* .*-ceph-.*//' /etc/hosts",
      # "sudo sh -c 'cat hosts.tmp >> /etc/hosts'",
      "sudo yum -y install epel-release",
      "sudo yum -y install ansible",
      "sudo yum -y install python-pip",
      "sudo pip install pexpect",
      "sudo pip install --upgrade jinja2", 
      "tar zxvf playbooks.tgz",
      "ssh-keygen -R localhost",
      "ssh -o StrictHostKeyChecking=no localhost date",
      "ansible-playbook -i \"localhost,\" playbooks/bastion.yml",
      "ansible-playbook -i \"localhost,\" playbooks/op-prereq.yml -e opname=${openstack_compute_instance_v2.op-posix.name} -e domain=${var.onezone}",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${openstack_networking_floatingip_v2.op-posix.address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${openstack_networking_floatingip_v2.op-posix.address} date"
  }
}

resource "null_resource" "op-posix-onedatify" { 
  depends_on = ["null_resource.prepare-op-posix"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/posix.yml -i \"localhost,\"",
      "ansible-playbook playbooks/oneprovider.yml -i \"localhost,\" --extra-vars \"domain=${var.onezone} support_token=${var.support_token_posix} storage_type=${var.storage_type_posix} oppass=${var.oppass} support_size=${var.support_size_posix} sync=y import= onedatify_install_script_version=${var.onedatify_install_script_version} onedatify_oneprovider_version=${var.onedatify_oneprovider_version}\"",
    ]
  }
}

resource "null_resource" "op-posix-desy" { 
  depends_on = ["null_resource.prepare-op-posix","null_resource.op-posix-onedatify","null_resource.op-ceph-oneclient"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy.yml -i \"localhost,\" --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} source_provider=${openstack_compute_instance_v2.op-ceph.name}.${var.onezone} destination_provider=${openstack_compute_instance_v2.op-posix.name}.${var.onezone} remote_host_ip=${openstack_networking_floatingip_v2.op-ceph.address}\"",
    ]
  }
}

resource "null_resource" "op-posix-desy-multi" { 
  depends_on = ["null_resource.prepare-op-posix","null_resource.op-posix-onedatify","null_resource.oneclients"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy-multi.yml -i \"localhost,\" --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} destination_provider=${openstack_compute_instance_v2.op-posix.name}.${var.onezone} ip_list=\\\"${join(" ", formatlist("%s", openstack_networking_floatingip_v2.client-nodes.*.address))}\\\"\"",
    ]
  }
}

resource "null_resource" "op-posix-collectd" { 
  depends_on = ["null_resource.provision-grafana"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-posix.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i \"localhost,\" --extra-vars \" grafana_ip=${openstack_networking_floatingip_v2.grafana.address} \"",
    ]
  }
}
