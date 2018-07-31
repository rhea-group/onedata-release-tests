resource "exoscale_compute" "grafana" {
  # depends_on = ["exoscale_affinity.op"]
  display_name =  "${var.project}-grafana"
  template = "Linux CentOS 7.4 64-bit"
  zone = "${var.zone}"
  size = "${var.grafana_flavor_name}"
  disk_size = 100
  key_pair = "${var.project}-exo"
  security_groups = ["${var.project}-ceph","${var.project}-op"]
  # affinity_groups = ["${var.project}-op"]
}

resource "null_resource" "provision-grafana" {
  depends_on = [ "exoscale_compute.grafana"]
  connection {
    host = "${exoscale_compute.op-ceph.ip_address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "180s"
  }
  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -R ${exoscale_compute.grafana.ip_address}",
      "ssh -o StrictHostKeyChecking=no ${exoscale_compute.grafana.ip_address} date",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i \"${exoscale_compute.grafana.ip_address},\" playbooks/grafana.yml",
    ]
  }
}
