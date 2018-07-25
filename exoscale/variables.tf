variable "exoscale_api_key" {
  type = "string"
}

variable "exoscale_secret_key" {
  type = "string"
}

variable "zone" {
  default = "de-fra-1"
}

# The user name for loging into the VMs.
variable "ssh_user_name" {
  default = "centos"
}

### Project Settings
# The name of the project. It is used to prefix VM names. It should be unique among
# OTC as it is used to create names of VMs. 
variable "project" {
   default = "odt"
}

### Onedata related variables

### Oneprovider
variable "oneprovider_flavor_name" {
  default = "s2.medium.8"
}

variable "opdomain" {
  default = "onedata.hnsc.otc-service.com"
}

variable "support_token_ceph" {
  default = "MDAxNWxvY2F00aW9uIG9uZXpvbmUKMDAzMGlkZW500aWZpZXIgMWJhZjY5MGFmYWZlMWEyNmY5MTNhNDE5MDI2Y2M00YTgKMDAyOGNpZCB00b2tlblR5cGUgPSBzcGFjZV9zdXBwb3J00X3Rva2VuCjAwMmZzaWduYXR1cmUgtd14JV0083f7s02AIhLIJG7Q3lPFTDxGms02972qP25lmcK"
}

variable "support_token_posix" {
  default = "MDAxNWxvY2F00aW9uIG9uZXpvbmUKMDAzMGlkZW500aWZpZXIgZDdjNWFmOGQyNTEzOWI1MTNjMGVkZWU5MmNlODc4YTIKMDAyOGNpZCB00b2tlblR5cGUgPSBzcGFjZV9zdXBwb3J00X3Rva2VuCjAwMmZzaWduYXR1cmUgNFb75zkB01sa3EY8IohFs2OahJ41quAvHjQ01oY02bwBxMK"
}

variable "oppass" {
  default = "odt-tst0xB."
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
  default = "/home/ubuntu/.ssh/id_rsa.pub"
}

variable "op-flavor" {
  default = "Huge"
}

variable "ceph-flavor" {
  default = "Medium"
}

### Ceph cluster settings

# The number of monitors of Ceph cluster. 
variable "ceph-mon_count" {
  default = "1"
}

# The number of VM for running OSDs.
variable "ceph-node_count" {
  default = "3"
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

