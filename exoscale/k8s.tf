resource "exoscale_affinity" "kube" {
  name = "${var.project}-kube"
  description = "Anti affinity group for the kube nodes"
  type = "host anti-affinity"
}

resource "exoscale_compute" "kube-ctlr" {
  count           = "${var.kube-ctlr_count}"
  display_name            = "${var.project}-kube-ctlr-${format("%02d", count.index+1)}"
  template      = "${var.image_name}"	
  size     = "${var.ctlr_flavor_name}"
  key_pair = "${var.project}-exo"
  zone = "${var.zone}"
  security_groups = ["${exoscale_security_group.ceph.name}"]
  disk_size = 100
}

resource "exoscale_compute" "kube-work" {
  count           = "${var.kube-work_count}"
  display_name            = "${var.project}-kube-work-${format("%02d", count.index+1)}"
  template      = "${var.image_name}"	
  size     = "${var.work_flavor_name}"
  key_pair = "${var.project}-exo"
  zone = "${var.zone}"
  security_groups = ["${exoscale_security_group.ceph.name}"]
  disk_size = 100
  affinity_groups = ["${exoscale_affinity.kube.name}"]
}

resource "null_resource" "provision-work" {
  count = "${var.kube-work_count}"
  connection {
    host     = "${element(exoscale_compute.kube-work.*.ip_address, count.index)}"
    user     = "${var.ssh_user_name}"
    agent = true
    timeout = 600
  }
  provisioner "remote-exec" {
    inline = [
      # "sudo systemctl disable firewalld",
      # "sudo systemctl stop firewalld",
      "echo NOP",
    ]
  }
}



resource "null_resource" "provision-kubespray" {
  depends_on = ["exoscale_compute.kube-work", "exoscale_compute.kube-ctlr", "null_resource.provision-work", "null_resource.prepare-op-ceph"]
  connection {
      host     = "${exoscale_compute.op-ceph.ip_address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "file" {
    content = "${join("\n", formatlist("%s ansible_host=%s", exoscale_compute.kube-ctlr.*.name, exoscale_compute.kube-ctlr.*.ip_address))}\n${join("\n", formatlist("%s ansible_host=%s", exoscale_compute.kube-work.*.name, exoscale_compute.kube-work.*.ip_address))}\n\n[kube-master]\n${join("\n", exoscale_compute.kube-ctlr.*.name)}\n\n[etcd]\n${join("\n", exoscale_compute.kube-ctlr.*.name)}\n\n[kube-node]\n${join("\n", exoscale_compute.kube-work.*.name)}\n\n[k8s-cluster:children]\nkube-node\nkube-master\n"
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
      host     = "${exoscale_compute.kube-ctlr.0.ip_address}"
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

resource "null_resource" "provision-miscafter" {
  depends_on = ["null_resource.provision-kubespray", "null_resource.provision-helm", "null_resource.local-setup"]
  connection {
      host     = "${exoscale_compute.op-ceph.ip_address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  # provisioner "file" {
  #   source = "../playbooks/kube-miscafter-exo.yml"
  #   destination = "/home/centos/playbooks/kube-miscafter-exo.yml"
  # }  
  # provisioner "file" {
  #   source = "../playbooks.tgz"
  #   destination = "playbooks.tgz"
  # }
  provisioner "remote-exec" {
    inline = [
      "tar zxvf playbooks.tgz",
      "ansible-playbook -i inventory-kube.ini playbooks/kube-miscafter-exo.yml -e dnszone=${var.dnszone} -e project=${var.project}",
    ]
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${exoscale_compute.kube-ctlr.0.ip_address}"
  }
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.ssh_user_name}@${exoscale_compute.kube-ctlr.0.ip_address} date"
  }

}

resource "null_resource" "provision-kube-jobs" {
  depends_on = ["null_resource.provision-grafana", "null_resource.provision-miscafter", "null_resource.prepare-op-ceph"]
  connection {
      host     = "${exoscale_compute.op-ceph.ip_address}"
      user     = "${var.ssh_user_name}"
      agent = true
  }
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i \"localhost,\" playbooks/tcp-count.yml",
      "ansible-playbook -i inventory-kube.ini playbooks/kube-jobs.yml -e \"grafana_ip=${exoscale_compute.grafana.ip_address} oneclient_oneprovider_host=${exoscale_compute.op-ceph.name}.${var.onezone} oneclient_access_token=${var.access_token} space_name=${var.space_name} oneclient_image=${var.oneclient_image} count_server_ip=${exoscale_compute.op-ceph.ip_address}\"",
    ]
  }
}

output "k8s master" {
  value = "${exoscale_compute.kube-ctlr.0.ip_address}"
}


