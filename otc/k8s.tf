
resource "openstack_networking_floatingip_v2" "kube-ctlr" {
  depends_on = ["openstack_compute_instance_v2.kube-ctlr"]
  port_id  = "${element(openstack_networking_port_v2.ctlr-port.*.id, count.index)}"
  count = "${var.kube-ctlr_count}"
  pool  = "${var.external_network}"
}

resource "openstack_blockstorage_volume_v2" "kube-ctlr-image-vols" {
  count           = "${var.kube-ctlr_count}"
  name = "${var.project}-${format("vol-%03d", count.index + 1)}"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_compute_instance_v2" "kube-ctlr" {
  depends_on = ["openstack_networking_router_interface_v2.interface"]
  count           = "${var.kube-ctlr_count}"
  name            = "${var.project}-kube-ctlr-${format("%02d", count.index+1)}"
  flavor_name     = "${var.ctlr_flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"
  network {
    port = "${element(openstack_networking_port_v2.ctlr-port.*.id, count.index)}"
    uuid = "${openstack_networking_network_v2.network.id}"
    access_network = true
  }
  block_device {
    uuid                  = "${element(openstack_blockstorage_volume_v2.kube-ctlr-image-vols.*.id, count.index)}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
}

resource "openstack_networking_port_v2" "ctlr-port" {
  count              = "${var.kube-ctlr_count}"
  network_id         = "${openstack_networking_network_v2.network.id}"
  security_group_ids = [
    # "${openstack_compute_secgroup_v2.secgrp_jmp.id}",
    "${openstack_compute_secgroup_v2.kube.id}",
    "${openstack_compute_secgroup_v2.ceph.id}"
  ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
  allowed_address_pairs = {
    ip_address = "1.1.1.1/0"
  }
}

resource "null_resource" "provision-work" {
  count = "${var.kube-work_count}"
  connection {
    bastion_host = "${openstack_networking_floatingip_v2.kube-ctlr.address}"
    bastion_user = "${var.ssh_user_name}"
    host     = "${element(openstack_compute_instance_v2.kube-work.*.access_ip_v4, count.index)}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = 600
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl disable firewalld",
      "sudo systemctl stop firewalld",
    ]
  }
}


#  resource "null_resource" "provision-post-kube" {
#   depends_on = ["null_resource.provision-kubespray"]
#   connection {
#       host     = "${openstack_networking_floatingip_v2.op-ceph.address}"
#       user     = "${var.ssh_user_name}"
#       agent = true
#   }
#   provisioner "file" {
#     source = "playbooks/post-kube/post-kube.yml"
#     destination = "/home/linux/playbooks/post-kube/post-kube.yml"
#   }  
#   provisioner "remote-exec" {
#     inline = [
#       "ansible-playbook -i inventory.ini playbooks/post-kube/post-kube.yml -e dnszone=${var.dnszone} -e project=${var.project}",      
#     ]
#   }
# }

resource "null_resource" "provision-miscafter" {
  depends_on = ["null_resource.provision-kubespray", "null_resource.provision-helm", "null_resource.local-setup"]
  connection {
      host     = "${openstack_networking_floatingip_v2.op-ceph.address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "remote-exec" {
    inline = [
      "tar zxvf playbooks.tgz",
      "ansible-playbook -i inventory-kube.ini playbooks/kube-miscafter-otc.yml -e dnszone=${var.dnszone} -e project=${var.project}",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${openstack_networking_floatingip_v2.op-ceph.address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${openstack_networking_floatingip_v2.op-ceph.address} date"
  }

}

# resource "null_resource" "provision-local-setup" {
#   depends_on = ["openstack_networking_floatingip_v2.kube-ctlr"]
#   provisioner "local-exec" {
#     command = "./local-setup.sh ${var.project} ${var.kube-ctlr_count} ${var.kube-work_count} 0 0"
#   }
# }

resource "null_resource" "provision-ctlr" {
  depends_on = [
    # "openstack_networking_floatingip_v2.kube-ctlr",
    # "null_resource.provision-work",
    # "null_resource.provision-local-setup",
  ]
  count = "${var.kube-ctlr_count}"
  connection {
      host     = "${element(openstack_networking_floatingip_v2.kube-ctlr.*.address, count.index)}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl disable firewalld",
      "sudo systemctl stop firewalld",
      "sudo sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",
    ]
  }
}

resource "openstack_blockstorage_volume_v2" "kube-work-image-vols" {
  count           = "${var.kube-work_count}"
  name = "${var.project}-${format("vol-%03d", count.index + 1)}"
  size = "${var.image_vol_size}"
  volume_type = "${var.image_vol_type}"
  availability_zone = "${var.otc_availability_zone}"
  image_id = "${var.image_uuid}"
}

resource "openstack_compute_instance_v2" "kube-work" {
  depends_on = ["openstack_networking_router_interface_v2.interface"]
  count           = "${var.kube-work_count}"
  name            = "${var.project}-kube-work-${format("%02d", count.index+1)}"
  flavor_name     = "${var.work_flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.otc.name}"
  availability_zone = "${var.otc_availability_zone}"

  network {
    port = "${element(openstack_networking_port_v2.work-port.*.id, count.index)}"
    uuid = "${openstack_networking_network_v2.network.id}"
    access_network = true
  }
  block_device {
    uuid                  = "${element(openstack_blockstorage_volume_v2.kube-work-image-vols.*.id, count.index)}"
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "openstack_networking_port_v2" "work-port" {
  count              = "${var.kube-work_count}"
  network_id         = "${openstack_networking_network_v2.network.id}"
  name = "${var.project}-work-${format("%02d", count.index+1)}"
  security_group_ids = [
    "${openstack_compute_secgroup_v2.kube.id}",
    "${openstack_compute_secgroup_v2.ceph.id}",
  ]
  admin_state_up     = "true"
  fixed_ip           = {
    subnet_id        = "${openstack_networking_subnet_v2.subnet.id}"
  }
  allowed_address_pairs = {
    ip_address = "1.1.1.1/0"
  }
}

resource "null_resource" "provision-kubespray" {
  depends_on = ["openstack_compute_instance_v2.kube-work", "openstack_compute_instance_v2.kube-ctlr", "null_resource.provision-work", "null_resource.prepare-op-ceph"]
  connection {
      host     = "${openstack_networking_floatingip_v2.op-ceph.address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", openstack_compute_instance_v2.kube-ctlr.*.name, openstack_compute_instance_v2.kube-ctlr.*.access_ip_v4))}\n${join("\n", formatlist("%s ansible_host=%s", openstack_compute_instance_v2.kube-work.*.name, openstack_compute_instance_v2.kube-work.*.access_ip_v4))}\n\n[kube-master]\n${join("\n", openstack_compute_instance_v2.kube-ctlr.*.name)}\n\n[etcd]\n${join("\n", openstack_compute_instance_v2.kube-ctlr.*.name)}\n\n[kube-node]\n${join("\n", openstack_compute_instance_v2.kube-work.*.name)}\n\n[k8s-cluster:children]\nkube-node\nkube-master\n"
    destination = "inventory-kube.ini"
  }
  provisioner "remote-exec" {
    inline = [
      # "tar zxvf playbooks.tgz",
      # "sudo yum -y install ansible",
      # "sudo yum -y install epel-release",
      # "sudo yum -y install python-pip",
      # "sudo pip install --upgrade jinja2",
      "sudo yum -y install python-netaddr",
      "sudo yum -y install git",
      # "sudo systemctl disable firewalld",
      # "sudo systemctl stop firewalld",
      "grep ansible_host inventory-kube.ini | cut -f2 -d= | xargs -I{} ssh -o StrictHostKeyChecking=no {} hostname",
      "cd playbooks; git clone -b v2.6.0 https://github.com/kubernetes-incubator/kubespray.git; cd ..",
      "sudo pip install -r playbooks/kubespray/requirements.txt",
      # "cd playbooks; tar zxvf ../kubespray.tgz; cd ..",
      "ansible-playbook -b -i inventory-kube.ini playbooks/kubespray/cluster.yml -e dashboard_enabled=true -e '{kubeconfig_localhost: true}' -e kube_network_plugin=flannel -e cluster_name=kube.${var.dnszone} -e domain_name=kube.${var.dnszone} -e kube_service_addresses=${var.kube_service_addresses} -e kube_pods_subnet=${var.kube_pods_subnet} -f 50 -T 30 -e docker_dns_servers_strict=no"
    ]
  }
}

resource "null_resource" "provision-helm" {
  depends_on = ["null_resource.provision-kubespray"]
  connection {
      host     = "${openstack_networking_floatingip_v2.kube-ctlr.0.address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "remote-exec" {
    inline = [
      "wget https://storage.googleapis.com/kubernetes-helm/helm-v2.8.1-linux-amd64.tar.gz",
      "tar zxf helm-v2.8.1-linux-amd64.tar.gz",
      "sudo mv linux-amd64/helm /usr/local/bin",
      "kubectl create clusterrolebinding helm-admin --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:default", # TODO: check if kubespray binds roles
      "helm init",
      "until helm ls; do echo Waiting for tiller...; sleep 1; done",
#      "sleep 5",
    ]
  }
}

resource "null_resource" "kube-nodes-collectd" { 
  depends_on = ["null_resource.provision-grafana"]
  connection {
    host = "${openstack_networking_floatingip_v2.op-ceph.address}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = "10m"
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook playbooks/collectd.yml -i inventory-kube.ini --extra-vars \" grafana_ip=${openstack_networking_floatingip_v2.grafana.address} \"",
    ]
  }
}

# data "template_file" "collectd" {
#   template = "${file("etc/collectd.conf.tpl")}"
#   vars {
#     graphite_host = "go-carbon.mon.svc.kube.${var.dnszone}"
#     # graphite_host = "${exoscale_compute.grafana.access_ip_v4}"
#   }
# }

# resource "null_resource" "provision-collectd" {
# #  count = "${var.client_count}"
#   depends_on = [ "null_resource.provision-landscape", ]
#   triggers {
# #    mount = "${element(null_resource.provision-clients-mount.*.id, count.index)}"
#     graphite = "go-carbon.mon.svc.kube.${var.dnszone}"
#   }
#   connection {
#     host     = "${exoscale_compute.kube-ctlr.0.ip_address}"
#     user     = "${var.ssh_user_name}"
#     agent = true
#     timeout = 600
#   }
#   provisioner "file" {
#     content = "${data.template_file.collectd.rendered}"
#     destination = "collectd.conf"
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "ansible-playbook -i inventory-kube.ini playbooks/miscafter/collectd.yml",
#     ]
#   }
# }

resource "null_resource" "provision-kube-jobs" {
  depends_on = ["null_resource.provision-grafana", "null_resource.provision-miscafter", "null_resource.prepare-op-ceph"]
  connection {
      host     = "${openstack_networking_floatingip_v2.op-ceph.address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i \"localhost,\" playbooks/tcp-count.yml",
      "ansible-playbook -i inventory-kube.ini playbooks/kube-jobs.yml -e \"grafana_ip=${openstack_compute_instance_v2.grafana.access_ip_v4} oneclient_oneprovider_host=${openstack_compute_instance_v2.op-ceph.name}.${var.onezone} oneclient_access_token=${var.access_token} space_name=${var.space_name} oneclient_image=${var.oneclient_image} count_server_ip=${openstack_compute_instance_v2.op-ceph.access_ip_v4} cloud=otc\"",
    ]
  }
}

output "k8s master" {
  value = "${openstack_networking_floatingip_v2.kube-ctlr.0.address}"
}


