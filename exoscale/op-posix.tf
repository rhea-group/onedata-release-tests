resource "exoscale_compute" "op-posix" {
#  depends_on = ["exoscale_affinity.op"]
  display_name =  "${var.project}-exo-op2"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone2}"
  size = "${var.op-posix-flavor}"
  disk_size = "${var.op-posix-disk}"
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
      "ansible-playbook playbooks/oneprovider.yml -i \"localhost,\" --extra-vars \"domain=${var.onezone} support_token=${var.support_token_posix} storage_type=${var.storage_type_posix} oppass=${var.oppass} support_size=${var.support_size_posix} sync=y import= onedatify_install_script_version=${var.onedatify_install_script_version} onedatify_oneprovider_version=${var.onedatify_oneprovider_version}\"",
    ]
  }
}

resource "null_resource" "op-posix-desy" { 
  depends_on = ["null_resource.op-posix-onedatify"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy.yml -i \"localhost,\" --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} source_provider=${exoscale_compute.op-ceph.name}.${var.onezone} destination_provider=${exoscale_compute.op-posix.name}.${var.onezone} remote_host_ip=${exoscale_compute.op-ceph.ip_address}\"",
    ]
  }
}

resource "null_resource" "op-posix-desy-multi" { 
  depends_on = ["null_resource.prepare-op-posix","null_resource.op-posix-onedatify","null_resource.oneclients"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy-multi.yml -i \"localhost,\" --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} destination_provider=${exoscale_compute.op-posix.name}.${var.onezone} ip_list=\\\"${join(" ", formatlist("%s", exoscale_compute.client-nodes.*.ip_address))}\\\"\"",
    ]
  }
}

resource "null_resource" "op-posix-collectd" { 
  depends_on = ["null_resource.provision-grafana"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i \"localhost,\" --extra-vars \" grafana_ip=${exoscale_compute.grafana.ip_address} \"",
    ]
  }
}
