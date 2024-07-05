resource "google_compute_instance" "k8s-worker" {
  count        = 2
  name         = "k8s-worker-${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOF
  #!/bin/bash
  set -e
  exec > >(sudo tee /var/log/startup-script.log) 2>&1
  echo "Starting worker node setup" | sudo tee -a /var/log/install.log
  sudo apt-get update | sudo tee -a /var/log/install.log

  # Adding Kubernetes APT repository and key
  sudo mkdir -p /etc/apt/keyrings | sudo tee -a /var/log/install.log
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg | sudo tee -a /var/log/install.log
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list | sudo tee -a /var/log/install.log
  sudo apt-get update | sudo tee -a /var/log/install.log
  sudo apt-get install -y apt-transport-https ca-certificates curl kubelet kubeadm kubectl docker.io | sudo tee -a /var/log/install.log
  sudo apt-mark hold kubelet kubeadm kubectl | sudo tee -a /var/log/install.log
  sudo systemctl enable docker | sudo tee -a /var/log/install.log
  sudo systemctl start docker | sudo tee -a /var/log/install.log

  # Ensure kubectl, kubeadm, and kubelet are in the PATH
  export PATH=$PATH:/usr/local/bin:/usr/bin:/bin

  # Retrieve the token, discovery hash, and master internal IP from Secret Manager
  TOKEN=$(sudo gcloud secrets versions access latest --secret=kubernetes-token)
  DISCOVERY_HASH=$(sudo gcloud secrets versions access latest --secret=kubernetes-hash)
  MASTER_INTERNAL_IP=$(sudo gcloud secrets versions access latest --secret=kubernetes-master-internal-ip)

  echo "Joining Kubernetes cluster with token $TOKEN and hash $DISCOVERY_HASH at master IP $MASTER_INTERNAL_IP" | sudo tee -a /var/log/install.log
  while ! sudo kubeadm join $MASTER_INTERNAL_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $DISCOVERY_HASH; do
    echo 'Waiting for master to be ready...' | sudo tee -a /var/log/install.log
    sleep 10
  done
EOF

  tags = ["k8s", "worker"]

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.kubernetes_key.public_key_openssh}"
  }

  depends_on = [
    null_resource.master_ready
  ]
}

resource "null_resource" "workers_ready" {
  count = length(google_compute_instance.k8s-worker)

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.username
      private_key = tls_private_key.kubernetes_key.private_key_pem
      host        = google_compute_instance.k8s-master.network_interface.0.access_config.0.nat_ip
    }

    inline = [
      "export KUBECONFIG=/home/${var.username}/.kube/config",
      "for node in ${join(" ", google_compute_instance.k8s-worker[*].name)}; do while true; do STATUS=$(kubectl get nodes $node -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'); if [ \"$STATUS\" = \"True\" ]; then echo \"Node $node is Ready.\"; break; else echo \"Waiting for node $node to be ready...\"; sleep 10; fi; done; done"
    ]
  }

  depends_on = [null_resource.master_ready]
}

