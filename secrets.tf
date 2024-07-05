resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
}

resource "tls_private_key" "kubernetes_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_secret_manager_secret" "kubernetes_key" {
  secret_id = "kubernetes-key"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "kubernetes_key_version" {
  secret      = google_secret_manager_secret.kubernetes_key.id
  secret_data = tls_private_key.kubernetes_key.private_key_pem
}

resource "null_resource" "wait_for_secret_version" {
  depends_on = [google_secret_manager_secret_version.kubernetes_key_version]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

data "google_secret_manager_secret_version" "kubernetes_key_version_data" {
  depends_on = [null_resource.wait_for_secret_version]
  secret  = google_secret_manager_secret.kubernetes_key.id
  version = "latest"
}

output "kubernetes_key" {
  value     = data.google_secret_manager_secret_version.kubernetes_key_version_data.secret_data
  sensitive = true
}

