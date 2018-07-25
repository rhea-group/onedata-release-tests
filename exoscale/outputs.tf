output "Ceph nodes addresses" {
  value = "${exoscale_compute.ceph-nodes.*.ip_address}"
}
output "Oneprovider with Ceph support" {
  value = "${exoscale_compute.op-ceph.ip_address}"
}
# output "Oneprovider with POSIX support" {
#   value = "${exoscale_compute.op-posix.ip_address}"
# }
