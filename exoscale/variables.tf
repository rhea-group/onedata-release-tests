variable "exoscale_api_key" {
  type = "string"
}

variable "exoscale_secret_key" {
  type = "string"
}

variable "zone" {
  default = "de-fra-1"
}

variable "zone2" {
#  default = "de-fra-1"
  default = "ch-gva-2"
}

# The user name for loging into the VMs.
variable "ssh_user_name" {
  default = "centos"
}

# The image name used for all instances
variable "image_name" {
  default = "Linux CentOS 7.4 64-bit"
}

### Project Settings
# The name of the project. It is used to prefix VM names. It should be unique among
# OTC as it is used to create names of VMs. 
variable "project" {
   default = "odt"
}

### Onedata related variables

variable "space_name" {
  default = "odt"
}

variable "access_token" {
  default = ""
}

variable "oneclient_image" {
  default = "onedata/oneclient:18.02.0-rc9"
}

### Oneprovider
# variable "oneprovider_flavor_name" {
#   default = "s2.medium.8"
# }

variable "opdomain" {
  default = "onedata.hnsc.otc-service.com"
}

variable "support_token_ceph" {
  default = "${ceph-support-token}"
}

variable "support_token_posix" {
  default = "${posix-support-token}"
}

variable "oppass" {
  default = "pass123."
}

variable "storage_type_ceph" {
  default = "ceph"
}

variable "support_size_ceph" {
  default = "1099511627776" # 1TB
}

variable "storage_type_posix" {
  default = "posix"
}

variable "support_size_posix" {
  default = "322122547200" # 300GB
}

variable "onezone" {
  default = "onedata.hnsc.otc-service.com"
}

variable "public_key_file" {
  default = "${public-key-path}"
}

variable "op-flavor" {
  default = "Huge"
}

### Ceph cluster settings
variable "ceph-flavor" {
  default = "Medium"
}


# The number of monitors of Ceph cluster. 
variable "ceph-mon_count" {
  default = "1"
}

# The number of VM for running OSDs.
variable "ceph-node_count" {
  default = "4"
}

# The size of elastic volumes which will be attached to the OSDs. The size is given in GB.
variable "vol_size" {
  default = "400"
}

# The number of disks to attach to each VM for running OSDs. The raw Ceph total capacity
# will be (osd_count * disks-per-osd_count * vol_size) GB.
variable "disks-per-osd_count" {
  default = "1"
}

# The disk device naming (prefix) for the given flavor.
variable "vol_prefix" {
   default = "/dev/vda2"
}

# k8s cluster settings
# Kube cidr for services - the default is 10.233.0.0/18
variable "kube_service_addresses" {
  default = "10.233.0.0/18"
}

# Kube cidr for pods - the default is 10.233.64.0/18
variable "kube_pods_subnet" {
  default = "10.233.64.0/18"
}

variable "dnszone" {
  default = "local"
}

# variable "email" {
# #  default = ""
# }

# ### The following variables can optionally be set. Reasonable defaults are provided.

# ### k8s cluster settings
# This is the number of contoller nodes.
variable "kube-ctlr_count" {
  default = "1"
}

# The number of workers of Kube cluster. 
variable "kube-work_count" {
  default = "2"
}

# ### VM (Instance) Settings
# # The flavor name used for Ceph monitors and OSDs. 
# variable "vpn_flavor_name" {
#   default = "h1.large.4"
# }

variable "ctlr_flavor_name" {
  default = "Extra-large"
}

variable "work_flavor_name" {
  default = "Huge"
}

