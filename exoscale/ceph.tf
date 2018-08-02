resource "exoscale_compute" "ceph-nodes" {
  count = "${var.ceph-node_count}"
  display_name =  "${var.project}-ceph-node-${format("%02d", count.index+1)}"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone}"
  size = "${var.ceph-flavor}"
  disk_size = 400
  key_pair = "${var.project}-exo"
  security_groups = ["${exoscale_security_group.ceph.name}"]
  affinity_groups = ["${exoscale_affinity.ceph.name}"]
  user_data = <<EOF
#cloud-config

manage_etc_hosts: false

growpart:
  mode: off
EOF
}

resource "null_resource" "reboot" {
  depends_on = ["exoscale_compute.ceph-nodes"]
  count = "${var.ceph-node_count}"
  connection {
    host     = "${element(exoscale_compute.ceph-nodes.*.ip_address, count.index)}"
    user     = "${var.ssh_user_name}"
    agent = true
  }
  provisioner "file" {
    source = "scripts/part-vda2.sh"
    destination = "part-vda2.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x part-vda2.sh",
      "sudo ./part-vda2.sh",
      "echo Rebooting...",
      "(sleep 2 && sudo reboot)&",
    ]
  }
}

resource "null_resource" "provision-ceph-node" {
  count = "${var.ceph-node_count}"
  depends_on = ["null_resource.bastion", "null_resource.reboot"]
  connection {
    bastion_host = "${exoscale_compute.op-ceph.ip_address}"
    host     = "${element(exoscale_compute.ceph-nodes.*.ip_address, count.index)}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "echo Connected ....",
      "sudo partprobe",
    ]
  }
}

resource "null_resource" "deploy-ceph" {
  depends_on = ["null_resource.local-setup","null_resource.provision-ceph-node","null_resource.prepare-op-ceph"]
  connection {
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
  }
  provisioner "file" {
    content = "\n# Ceph nodes\n${join("\n", formatlist("%s %s", exoscale_compute.ceph-nodes.*.ip_address, exoscale_compute.ceph-nodes.*.name))}\n"
    destination = "ceph-nodes.tmp"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s",exoscale_compute.ceph-nodes.*.name,exoscale_compute.ceph-nodes.*.ip_address))}\n[mgt]\nlocalhost\n\n[mons]\n${join("\n", slice(exoscale_compute.ceph-nodes.*.name,0,var.ceph-mon_count))}\n\n[osds]\n${join("\n",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}"
    destination = "inventory-ceph.ini"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/[0-9.]* .*-ceph-.*//' /etc/hosts",
      "sudo sh -c 'cat ceph-nodes.tmp >> /etc/hosts'",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "for i in ${join(" ",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}; do ssh-keygen -R $i; done",
      "for i in ${join(" ",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}; do ssh -o StrictHostKeyChecking=no $i date; done",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/myceph/myceph.yml -i inventory-ceph.ini --extra-vars \"osd_disks=${var.disks-per-osd_count} vol_prefix=${var.vol_prefix}\" -f 50 -T 30",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${exoscale_compute.ceph-nodes.0.ip_address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${exoscale_compute.ceph-nodes.0.ip_address} date"
  }
}

resource "exoscale_security_group" "ceph" {
  name = "${var.project}-ceph"
}

resource "exoscale_security_group_rule" "ceph-ssh" {
  security_group_id = "${exoscale_security_group.ceph.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 22
  end_port = 22
}

resource "exoscale_security_group_rule" "same-group-tcp" {
  security_group_id = "${exoscale_security_group.ceph.id}"
  protocol = "TCP"
  type = "INGRESS"
  user_security_group = "${var.project}-ceph"  
  start_port = 1
  end_port = 65535
}

resource "exoscale_security_group_rule" "same-group-udp" {
  security_group_id = "${exoscale_security_group.ceph.id}"
  protocol = "UDP"
  type = "INGRESS"
  user_security_group = "${var.project}-ceph"  
  start_port = 1
  end_port = 65535
}

resource "exoscale_security_group_rule" "same-group-ping" {
  security_group_id = "${exoscale_security_group.ceph.id}"
  protocol = "ICMP"
  type = "INGRESS"
  user_security_group = "${var.project}-ceph"  
  # start_port = 0
  # end_port = 0
  icmp_code = 0
  icmp_type = 8
}

