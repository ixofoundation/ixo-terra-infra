# NOTES:
# This uses the kubernetes-sigs scripts to run and create the K8 resources.
# This script has checks in place to not fail if resources exist, it also installs and uses kustomize.
# To re-apply: terraform state rm module.gce_csi_driver.null_resource.deploy_csi_driver
# https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver/tree/master
resource "null_resource" "deploy_csi_driver" {
  provisioner "local-exec" {
    command = "${path.module}/gcp-compute-persistent-disk-csi-driver/deploy/kubernetes/delete-driver.sh"
    environment = {
      GCE_PD_SA_DIR                  = var.service_account_dir
      GCE_PD_DRIVER_VERSION          = var.driver_version
      PKGDIR                         = "${path.module}/gcp-compute-persistent-disk-csi-driver"
      GOOGLE_APPLICATION_CREDENTIALS = "${var.service_account_dir}/cloud-sa.json"
      KUBECONFIG                     = var.kubeconfig_path
    }
  }
}

resource "kubernetes_storage_class_v1" "gce_storage_class" {
  depends_on = [null_resource.deploy_csi_driver]
  metadata {
    name = "gce-pd-balanced"
  }
  storage_provisioner    = "pd.csi.storage.gke.io"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type : "pd-balanced"
  }
}