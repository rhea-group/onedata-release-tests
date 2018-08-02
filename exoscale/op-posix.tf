resource "exoscale_compute" "op-posix" {
#  depends_on = ["exoscale_affinity.op"]
  display_name =  "${var.project}-exo-op2"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone2}"
  size = "${var.op-flavor}"
  disk_size = 400
  key_pair = "${var.project}-exo"
  security_groups = ["${exoscale_security_group.op.name}"]
  affinity_groups = ["${exoscale_affinity.op.name}"]
}

resource "null_resource" "prepare-op-posix" {
  depends_on = ["null_resource.local-setup"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
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
      "ansible-playbook -i \"localhost,\" playbooks/op-prereq.yml -e opname=${exoscale_compute.op-posix.name} -e domain=${var.onezone}",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${exoscale_compute.op-posix.ip_address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${exoscale_compute.op-posix.ip_address} date"
  }
}

resource "null_resource" "op-posix-onedatify" { 
  depends_on = ["null_resource.prepare-op-posix"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/posix.yml -i \"localhost,\"",
      "ansible-playbook playbooks/oneprovider.yml -i \"localhost,\" --extra-vars \"domain=${var.onezone} support_token=${var.support_token_posix} storage_type=${var.storage_type_posix} oppass=${var.oppass} support_size=${var.support_size_posix} sync=y import= \"",
    ]
  }
}
