resource "google_compute_firewall" "default" {
  name    = "default-allow-ssh-${random_id.firewall_id.hex}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s"]
}

resource "google_compute_firewall" "k8s" {
  name    = "k8s-allow-internal"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.128.0.0/9"]
  target_tags   = ["k8s"]
}

resource "random_id" "firewall_id" {
  byte_length = 8
}

