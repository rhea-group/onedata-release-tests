resource "exoscale_compute" "client-nodes" {
  count = "${var.client_count}"
  display_name =  "${var.project}-client-${format("%02d", count.index+1)}"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone}"
  size = "${var.client_flavor}"
  disk_size = 50
  key_pair = "${var.project}-exo"
  security_groups = ["${exoscale_security_group.ceph.name}"]
}


resource "null_resource" "oneclients" {
  depends_on = ["null_resource.op-ceph-onedatify"]
  connection {
    # host = "${element(openstack_networking_floatingip_v2.client-nodes.*.address, count.index)}"
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", exoscale_compute.client-nodes.*.name, exoscale_compute.client-nodes.*.ip_address))}\n[clients]\n${join("\n", exoscale_compute.client-nodes.*.name)}\n"
    destination = "inventory-clients.ini"
  }
  provisioner "remote-exec" {
    inline = [  
      "grep ansible_host inventory-clients.ini | cut -f2 -d= | xargs -I{} ssh -o StrictHostKeyChecking=no {} hostname",
      "ansible-playbook playbooks/oneclients.yml -i inventory-clients.ini --extra-vars \"oneprovider=${exoscale_compute.op-ceph.name}.${var.onezone} access_token=${var.access_token} oneclient_package=${var.oneclient_package} grafana_ip=${exoscale_compute.grafana.ip_address}\"",
    ]
  }
}

output "Oneclients nodes addresses" {
  value = "${exoscale_compute.client-nodes.*.ip_address}"
}
