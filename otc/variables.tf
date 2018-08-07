### Project Settings
# The name of the project. It is used to prefix VM names. It should be unique among
# OTC as it is used to create names of VMs. 
variable "project" {
   default = "myproject"
}

variable "public_key_file" {
  default = "/home/ubuntu/.ssh/id_rsa.pub"
}

### VPC
variable "vpc_subnet" {
  default = "192.168.7.0/24"
}

### Onedata related variables

variable "space_name" {
  default = "odt-otc"
}

variable "access_token" {
  default = ""
}

variable "onedata_version" {
  default = "18.02.0-rc10"
}

variable "onedatify_version" {
  default = "18.02.0-rc9"
}
# variable "oneclient_image" {
#   default = "onedata/oneclient:18.02.0-rc9"
# }

### Oneprovider
variable "op_flavor_name" {
  #default = "s2.medium.8"
  default = "h2.3xlarge.10"
}

variable "op-posix_flavor_name" {
  #default = "s2.medium.8"
  default = "h1.2xlarge.8"
}

variable "op-posix-vol_size" {
  default = "3000"
}

variable "opdomain" {
  default = "onedata.hnsc.otc-service.com"
}

variable "support_token_ceph" {
  default = "MDAxNWxvY2F00aW9uIG9uZXpvbmUKMDAzMGlkZW500aWZpZXIgNzg3NGY4YjQwYzM4YjVjOWRjNzNkZTk4M2IxMDQyYjcKMDAyOGNpZCB00b2tlblR5cGUgPSBzcGFjZV9zdXBwb3J00X3Rva2VuCjAwMmZzaWduYXR1cmUgvrJ6kqWUozLxFqLkiqeDtlU00qPPZn9q2BGJtfiAoVrUK"
}

variable "support_token_posix" {
  default = "MDAxNWxvY2F00aW9uIG9uZXpvbmUKMDAzMGlkZW500aWZpZXIgZjMxZDA5N2IzYzY4ZDcyM2QyM2VjZmFiZDU3ZDMyZTIKMDAyOGNpZCB00b2tlblR5cGUgPSBzcGFjZV9zdXBwb3J00X3Rva2VuCjAwMmZzaWduYXR1cmUgVYUFoOJnSE6G20121orQS8Lb5S02mV00hg1yjyw6VuGj01QK"
}

variable "oppass" {
  default = "pass123."
}

variable "storage_type_ceph" {
  default = "ceph"
}

variable "support_size_ceph" {
#  default = "1099511627776" # 1TB
  default = "8796093022208" # 8TB
}

variable "storage_type_posix" {
  default = "posix"
}

variable "support_size_posix" {
#  default = "322122547200" # 300GB
  default = "3298534883328" # 3TB
  
}

variable "onezone" {
  default = "onedata.hnsc.otc-service.com"
}

### Grafana
variable "grafana_flavor_name" {
  default = "s2.large.4"
}


### Ceph
# The number of monitors of Ceph cluster. 
variable "ceph-mon_count" {
  default = "1"
}

# The number of VM for running OSDs.
variable "ceph-node_count" {
  default = "2"
}

### VM (Instance) Settings
# The flavor name used for Ceph monitors and OSDs. 
variable "ceph_node_flavor" {
  default = "h2.3xlarge.10"
  # default = "hl1.8xlarge.8"
  # default = "h1.xlarge.4"
  # default = "s2.xlarge.8"
  # default = "s2.medium.8"
}

# The size of elastic volumes which will be attached to the OSDs. The size is given in GB.
variable "vol_size" {
  default = "100"
}

# The size of RAM disk used for OSD. The size is given in GB. 
variable "ramdisk_size" {
  default = "4"
}

# The type volume. It specifies the performance of a volume. "SSD" maps to "Ultra High I/O".
variable "vol_type" {
#  default = "co-p1"
  #  default = "uh-l1"
  default = "SSD"
}

# The number of disks to attach to each VM for running OSDs. The raw Ceph total capacity
# will be (osd_count * disks-per-osd_count * vol_size) GB.
variable "disks-per-osd_count" {
  default = "0"
}

# The disk device naming (prefix) for the given flavor.
variable "vol_prefix" {
 # default = "/dev/xvd"
 # default = "/dev/vd"
 #  default = "/dev/ram"
  default = "/dev/nvme"
}


### Kube
# Kube cidr for services - the default is 10.233.0.0/18
variable "kube_service_addresses" {
  default = "10.233.0.0/18"
}

# Kube cidr for pods - the default is 10.233.64.0/18
variable "kube_pods_subnet" {
  default = "10.233.64.0/18"
}

# This is the number of Kube contoller nodes.
variable "kube-ctlr_count" {
  default = "1"
}

# The number of workers of Kube cluster. 
variable "kube-work_count" {
  default = "2"
}

variable "ctlr_flavor_name" {
  default = "h1.xlarge.8"
  # default = "s2.medium.8" # for initial testing of tf scripts
}

variable "work_flavor_name" {
  # default = "h1.xlarge.8"
  default = "h2.3xlarge.10"
}

### The following variables can optionally be set. Reasonable defaults are provided.

### k8s cluster settings
### VM (Instance) Settings
# The flavor name used for Ceph monitors and OSDs. 
# variable "vpn_flavor_name" {
#   default = "h1.large.4"
# }

### General settings
variable "image_uuid" {
  # Standard_CentOS_7_latest
  default = "b7380d84-0681-4788-ad2c-a9cbee00a1f2"
}

variable "image_vol_size" {
  default = "50"
}

variable "dnszone" {
  default = "local"
}

variable "image_vol_type" {
  default = "SSD"
}

### OTC Specific Settings
# OpenStack Credentials
variable "otc_username" {}

variable "otc_password" {}

variable "otc_domain_name" {}

variable "otc_availability_zone" {
  default = "eu-de-01"
}

variable "otc_availability_zone2" {
  default = "eu-de-01"
}

variable "otc_tenant_name" {
  default = "eu-de"
}

variable "otc_endpoint" {
  default = "https://iam.eu-de.otc.t-systems.com:443/v3"
}

variable "external_network" {
  default = "admin_external_net"
}

#### Internal usage variables ####
# The user name for loging into the VMs.
variable "ssh_user_name" {
  default = "linux"
}


