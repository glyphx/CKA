resource "google_compute_instance" "k8s-master" {
  name         = "k8s-master"
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
  echo "Starting master node setup" | sudo tee -a /var/log/install.log
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

  # Set the internal IP
  MASTER_INTERNAL_IP=$(hostname -I | awk '{print $1}')

  echo "Initializing Kubernetes master" | sudo tee -a /var/log/install.log
  sudo kubeadm init --control-plane-endpoint="$MASTER_INTERNAL_IP:6443" --pod-network-cidr=10.244.0.0/16 | sudo tee -a /var/log/install.log

  # Set up kubeconfig for user
  sudo mkdir -p /home/${var.username}/.kube | sudo tee -a /var/log/install.log
  sudo cp -i /etc/kubernetes/admin.conf /home/${var.username}/.kube/config | sudo tee -a /var/log/install.log
  sudo chown ${var.username}:${var.username} /home/${var.username}/.kube/config | sudo tee -a /var/log/install.log

  # Ensure the kubeconfig is used
  echo "export KUBECONFIG=/home/${var.username}/.kube/config" | sudo tee -a /home/${var.username}/.bashrc
  export KUBECONFIG=/home/${var.username}/.kube/config

  # Ensure the necessary sysctl params are set
  sudo sysctl net.bridge.bridge-nf-call-iptables=1 | sudo tee -a /var/log/install.log

  # Create and store the join token, hash, and control plane join command in Secret Manager
  JOIN_CMD=$(sudo kubeadm token create --print-join-command)
  CERTIFICATE_OUTPUT=$(sudo kubeadm init phase upload-certs --upload-certs)
  CERTIFICATE_KEY=$(echo "$CERTIFICATE_OUTPUT" | grep -A 1 'Using certificate key:' | tail -n 1 | xargs)
  CONTROL_PLANE_JOIN_CMD="$JOIN_CMD --control-plane --certificate-key $CERTIFICATE_KEY"
  TOKEN=$(echo $JOIN_CMD | awk '{print $5}')
  DISCOVERY_HASH=$(echo $JOIN_CMD | awk '{print $7}')
  
  echo $CONTROL_PLANE_JOIN_CMD > /tmp/control_plane_join_cmd.txt
  echo $TOKEN > /tmp/token.txt
  echo $DISCOVERY_HASH > /tmp/hash.txt
  echo $MASTER_INTERNAL_IP > /tmp/internal_ip.txt

  # Store the token, hash, and internal IP in Google Secret Manager
  if ! gcloud secrets describe kubernetes-token > /dev/null 2>&1; then
    gcloud secrets create kubernetes-token --data-file=/tmp/token.txt
  else
    gcloud secrets versions add kubernetes-token --data-file=/tmp/token.txt
  fi

  if ! gcloud secrets describe kubernetes-hash > /dev/null 2>&1; then
    gcloud secrets create kubernetes-hash --data-file=/tmp/hash.txt
  else
    gcloud secrets versions add kubernetes-hash --data-file=/tmp/hash.txt
  fi

  if ! gcloud secrets describe kubernetes-master-internal-ip > /dev/null 2>&1; then
    gcloud secrets create kubernetes-master-internal-ip --data-file=/tmp/internal_ip.txt
  else
    gcloud secrets versions add kubernetes-master-internal-ip --data-file=/tmp/internal_ip.txt
  fi

  if ! gcloud secrets describe kubernetes-control-plane-join-cmd > /dev/null 2>&1; then
    gcloud secrets create kubernetes-control-plane-join-cmd --data-file=/tmp/control_plane_join_cmd.txt
  else
    gcloud secrets versions add kubernetes-control-plane-join-cmd --data-file=/tmp/control_plane_join_cmd.txt
  fi
  echo "Applying Flannel network" | sudo tee -a /var/log/install.log
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | sudo tee -a /var/log/install.log
EOF

  tags = ["k8s", "master"]

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.username}:${tls_private_key.kubernetes_key.public_key_openssh}"
  }
}

resource "null_resource" "master_ready" {
  depends_on = [google_compute_instance.k8s-master]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.username
      private_key = tls_private_key.kubernetes_key.private_key_pem
      host        = google_compute_instance.k8s-master.network_interface.0.access_config.0.nat_ip
    }

    inline = [
      "export KUBECONFIG=/home/${var.username}/.kube/config",
      "while ! kubectl get nodes | grep 'Ready' | grep 'control-plane'; do echo 'Waiting for Kubernetes master to be ready...' | sudo tee -a /var/log/install.log && sleep 10; done"
    ]
  }
}
