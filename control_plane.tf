resource "google_compute_instance" "k8s-control-plane" {
  count        = 1
  name         = "k8s-control-plane-${count.index}"
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
  echo "Starting control plane node setup" | sudo tee -a /var/log/install.log
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

  # Retrieve the control plane join command from Secret Manager
  CONTROL_PLANE_JOIN_CMD=$(sudo gcloud secrets versions access latest --secret=kubernetes-control-plane-join-cmd)

  echo "Joining Kubernetes cluster as control plane with join command: $CONTROL_PLANE_JOIN_CMD" | sudo tee -a /var/log/install.log
  while ! $CONTROL_PLANE_JOIN_CMD; do
    echo 'Waiting for master to be ready...' | sudo tee -a /var/log/install.log
    sleep 10
  done

  # Set up kubeconfig for user
  sudo mkdir -p /home/${var.username}/.kube | sudo tee -a /var/log/install.log
  sudo cp -i /etc/kubernetes/admin.conf /home/${var.username}/.kube/config | sudo tee -a /var/log/install.log
  sudo chown ${var.username}:${var.username} /home/${var.username}/.kube/config | sudo tee -a /var/log/install.log

  # Ensure the kubeconfig is used
  echo "export KUBECONFIG=/home/${var.username}/.kube/config" | sudo tee -a /home/${var.username}/.bashrc
  export KUBECONFIG=/home/${var.username}/.kube/config

  # Ensure the necessary sysctl params are set
  sudo sysctl net.bridge.bridge-nf-call-iptables=1 | sudo tee -a /var/log/install.log
EOF

  tags = ["k8s", "control-plane"]

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

resource "null_resource" "control_plane_ready" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.username
      private_key = tls_private_key.kubernetes_key.private_key_pem
      host        = google_compute_instance.k8s-master.network_interface.0.access_config.0.nat_ip
    }

    inline = [
      "export KUBECONFIG=/home/${var.username}/.kube/config",
      "for node in ${join(" ", concat([google_compute_instance.k8s-master.name], google_compute_instance.k8s-control-plane[*].name))}; do while true; do STATUS=$(kubectl get nodes $node -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'); if [ \"$STATUS\" = \"True\" ]; then echo \"Node $node is Ready.\"; break; else echo \"Waiting for node $node to be ready...\"; sleep 10; fi; done; done"
    ]
  }

  depends_on = [google_compute_instance.k8s-control-plane]
}

