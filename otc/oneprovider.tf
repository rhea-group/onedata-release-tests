resource "openstack_networking_floatingip_v2" "op-ceph" {
  depends_on = ["openstack_compute_instance_v2.op-ceph"]
  port_id  = "${openstack_networking_port_v2.op-ceph-port.id}"
  # count = "${var.provider_count}"
  pool  = "${var.external_network}"
}


resource "openstack_compute_instance_v2" "op-ceph" {
  depends_on = ["openstack_networking_router_interface_v2.interface"]
  name            = "${var.project}-otc-op"
  # image_name      = "${var.image_name}"
  flavor_name     = "${var.op_flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"

  network {
    port = "${openstack_networking_port_v2.op-ceph-port.id}"
    uuid = "${openstack_networking_network_v2.network.id}"
    access_network = true
  }
    block_device {
    uuid                  = "${openstack_blockstorage_volume_v2.op-ceph-image-vol.id}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_blockstorage_volume_v2" "op-ceph-image-vol" {
  name = "${var.project}-op-vol"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_networking_port_v2" "op-ceph-port" {
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

resource "null_resource" "bastion" {
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",
      "sleep 5",
    ]
  }
}

resource "null_resource" "local-setup" {
  provisioner "local-exec" {
    command = "scripts/local-setup.sh"
  }
}

resource "null_resource" "prepare-op-ceph" { # oneprivider will act as bastion
  depends_on = ["null_resource.local-setup", "null_resource.bastion"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "file" {
    source = "../playbooks.tgz"
    destination = "playbooks.tgz"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install epel-release",
      "sudo yum -y install ansible",
      "sudo yum -y install python-pip",
      "sudo pip install pexpect",
      "sudo pip install --upgrade jinja2", 
      "tar zxvf playbooks.tgz",
      "ssh-keygen -R localhost",
      "ssh -o StrictHostKeyChecking=no localhost date",
      "ansible-playbook -i \"localhost,\" playbooks/bastion.yml",
      "ansible-playbook -i \"localhost,\" playbooks/op-prereq.yml -e opname=${openstack_compute_instance_v2.op-ceph.name} -e domain=${var.opdomain}"
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${openstack_networking_floatingip_v2.op-ceph.address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no linux@${openstack_networking_floatingip_v2.op-ceph.address} date"
  }
}

resource "null_resource" "op-ceph-onedatify" { 
  depends_on = ["null_resource.provision-ceph","null_resource.prepare-op-ceph"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [  
      "ansible-playbook playbooks/oneprovider.yml -i \"localhost,\" --extra-vars \"domain=${var.onezone} support_token=${var.support_token_ceph} storage_type=${var.storage_type_ceph} oppass=${var.oppass} support_size=${var.support_size_ceph} sync=n import=noimort onedatify_install_script_version=${var.onedatify_install_script_version} onedatify_oneprovider_version=${var.onedatify_oneprovider_version}\"",
    ]
  }
}

resource "null_resource" "op-ceph-oneclient" { 
  depends_on = ["null_resource.op-ceph-onedatify"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [  
      "ansible-playbook playbooks/oneclient.yml -i \"localhost,\" --extra-vars \"oneprovider=${openstack_compute_instance_v2.op-ceph.name}.${var.onezone} access_token=${var.access_token} oneclient_package=${var.oneclient_package} grafana_ip=${openstack_networking_floatingip_v2.grafana.address}\"",
    ]
  }
}

resource "null_resource" "op-ceph-collectd" { 
  depends_on = ["null_resource.provision-grafana"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
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
