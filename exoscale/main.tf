provider "exoscale" {
  key = "${var.exoscale_api_key}"
  secret = "${var.exoscale_secret_key}"
}

resource "exoscale_ssh_keypair" "exo" {
  name = "${var.project}-exo"
  public_key = "${file("${var.public_key_file}")}"
}

resource "exoscale_affinity" "ceph" {
  name = "${var.project}-ceph"
  description = "Anti affinity group for the ceph nodes"
  type = "host anti-affinity"
}

resource "exoscale_affinity" "op" {
  name = "${var.project}-op"
  description = "Anti affinity group for the oneprovider nodes"
  type = "host anti-affinity"
}

resource "exoscale_compute" "op-ceph" {
  depends_on = ["exoscale_affinity.op"]
  display_name =  "${var.project}-exo-op"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone}"
  size = "${var.op-flavor}"
  disk_size = 100
  key_pair = "${var.project}-exo"
  security_groups = ["${var.project}-ceph","${var.project}-op"]
  affinity_groups = ["${var.project}-op"]
}

resource "null_resource" "bastion" {
  depends_on = [ "null_resource.reboot" ]
  connection {
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config",
      #"sudo sed -i 's/PermitTunnel no/PermitTunnel yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",
      "sleep 5",
      # "sudo yum -y install ansible",
      # "sudo yum -y install epel-release",
      # "sudo yum -y install python-pip",
      # "sudo pip install --upgrade jinja2",
      # "sudo systemctl stop firewalld",
      # "sudo systemctl disable firewalld",
    ]
  }
}

resource "null_resource" "local-setup" {
  provisioner "local-exec" {
    command = "scripts/local-setup.sh"
  }
}

resource "null_resource" "prepare-op-ceph" {
  depends_on = ["null_resource.local-setup","null_resource.provision-ceph-node"]
  connection {
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
  }
  provisioner "file" {
    source = "../playbooks.tgz"
    destination = "playbooks.tgz"
  }
  # provisioner "file" {
  #   content = "\n# Ceph nodes\n${join("\n", formatlist("%s %s", exoscale_compute.ceph-nodes.*.ip_address, exoscale_compute.ceph-nodes.*.name))}\n"
  #   destination = "ceph-nodes.tmp"
  # }
  # provisioner "file" {
  #   content = "${join("\n", formatlist("%s ansible_host=%s",exoscale_compute.ceph-nodes.*.name,exoscale_compute.ceph-nodes.*.ip_address))}\n[mgt]\nlocalhost\n\n[mons]\n${join("\n", slice(exoscale_compute.ceph-nodes.*.name,0,var.ceph-mon_count))}\n\n[osds]\n${join("\n",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}"
  #   destination = "inventory-ceph.ini"
  # }
  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo sed -i 's/[0-9.]* .*-ceph-.*//' /etc/hosts",
  #     "sudo sh -c 'cat ceph-nodes.tmp >> /etc/hosts'",
  #   ]
  # }
  # provisioner "remote-exec" {
  #   inline = [
  #     "for i in ${join(" ",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}; do ssh-keygen -R $i; done",
  #     "for i in ${join(" ",formatlist("%s",exoscale_compute.ceph-nodes.*.name))}; do ssh -o StrictHostKeyChecking=no $i date; done",
  #   ]
  # }
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
      "ansible-playbook -i \"localhost,\" playbooks/op-prereq.yml -e opname=${exoscale_compute.op-ceph.name} -e domain=${var.onezone}",
      # "ansible-playbook playbooks/myceph/myceph.yml -i inventory-ceph.ini --extra-vars \"osd_disks=${var.disks-per-osd_count} vol_prefix=${var.vol_prefix}\" -f 50 -T 30",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${exoscale_compute.op-ceph.ip_address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${exoscale_compute.op-ceph.ip_address} date"
  }
}

resource "null_resource" "op-ceph-onedatify" { 
  depends_on = ["null_resource.prepare-op-ceph"]
  connection {
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [  
      "ansible-playbook playbooks/oneprovider.yml -i \"localhost,\" --extra-vars \"domain=${var.onezone} support_token=${var.support_token_ceph} storage_type=${var.storage_type_ceph} oppass=${var.oppass} support_size=${var.support_size_ceph} sync=n import=noimort\"",
    ]
  }
}

resource "exoscale_security_group" "op" {
  name = "${var.project}-op"
}

resource "exoscale_security_group_rule" "op-ssh" {
  security_group_id = "${exoscale_security_group.op.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 22
  end_port = 22
}

resource "exoscale_security_group_rule" "http" {
  security_group_id = "${exoscale_security_group.op.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 80
  end_port = 80
}

resource "exoscale_security_group_rule" "https" {
  security_group_id = "${exoscale_security_group.op.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 443
  end_port = 443
}

resource "exoscale_security_group_rule" "rtransfer" {
  security_group_id = "${exoscale_security_group.op.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 6665
  end_port = 6665
}

resource "exoscale_security_group_rule" "onepanel" {
  security_group_id = "${exoscale_security_group.op.id}"
  protocol = "TCP"
  type = "INGRESS"
  cidr = "0.0.0.0/0"  # "::/0" for IPv6
  start_port = 9443
  end_port = 9443
}
