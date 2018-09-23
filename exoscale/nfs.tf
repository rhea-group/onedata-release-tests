resource "exoscale_compute" "nfs-clients" {
  count = "${var.nfs_client_count}"
  display_name =  "${var.project}-nfs-client-${format("%02d", count.index+1)}"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone2}"
  size = "${var.nfs_client_flavor}"
  disk_size = 50
  key_pair = "${var.project}-exo"
  security_groups = ["${exoscale_security_group.ceph.name}"]
}

resource "null_resource" "op-posix-nfs" { 
  depends_on = ["null_resource.op-posix-onedatify"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s",exoscale_compute.nfs-clients.*.name,exoscale_compute.nfs-clients.*.ip_address))}\n[server]\nlocalhost\n\n[clients]\n${join("\n", slice(exoscale_compute.nfs-clients.*.name,0,var.nfs_client_count))}\n"
    destination = "inventory-nfs.ini"
  }
  provisioner "remote-exec" {
    inline = [
      "grep ansible_host inventory-nfs.ini | cut -f2 -d= | xargs -I{} ssh -o StrictHostKeyChecking=no {} hostname",
      "ansible-playbook playbooks/nfs.yml -i inventory-nfs.ini --extra-vars \" nfs_clients_ips=${join(",", formatlist("%s", exoscale_compute.nfs-clients.*.ip_address))} nfs_server_ip=${exoscale_compute.op-posix.ip_address}\"",
    ]
  }
}

resource "null_resource" "nfs-client-desy-multi" { 
  depends_on = ["null_resource.prepare-op-posix","null_resource.op-posix-onedatify","null_resource.oneclients","null_resource.op-posix-nfs"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/desy-multi.yml -i inventory-nfs.ini --extra-vars \" access_token=${var.access_token} onezone=${var.onezone} space_name=${var.space_name} destination_provider=${exoscale_compute.op-posix.name}.${var.onezone} ip_list=\\\"${join(" ", formatlist("%s", exoscale_compute.client-nodes.*.ip_address))}\\\"\"",
    ]
  }
}

resource "null_resource" "nfs-client-collectd" {
  depends_on = ["null_resource.provision-grafana","null_resource.op-posix-nfs"]
  connection {
    host = "${exoscale_compute.op-posix.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i inventory-nfs.ini --extra-vars \" grafana_ip=${exoscale_compute.grafana.ip_address} \"",
    ]
  }
}

output "NFS clients addresses" {
  value = "${exoscale_compute.nfs-clients.*.ip_address}"
}

