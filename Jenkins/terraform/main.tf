## VPS Instance

provider "google" {
  credentials = file(var.service_account_key_path)
  project     = var.project_id
  region      = "europe-west1"
}

resource "tls_private_key" "jenkins_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "google_compute_instance" "jenkins" {
  name         = "jenkins-server"
  machine_type = "n1-standard-2" # 2 vCPUs, 7.5 GB memory
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "debian:${tls_private_key.jenkins_ssh_key.public_key_openssh}"
  }

  tags = ["http-server", "https-server"]

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

output "jenkins_ssh_private_key" {
  value     = tls_private_key.jenkins_ssh_key.private_key_pem
  sensitive = true
}

resource "google_compute_firewall" "default" {
  name    = "allow-http-https-jenkins"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "443"]
  }

  target_tags   = ["http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
}

## Kubernetes Cluster

resource "google_container_cluster" "kubernetes_cluster" {
  name     = "kubernetes-cluster"
  location = "europe-west1"
  deletion_protection = false

  node_config {
    machine_type = "g1-small" # 1 vCPU, 0.6 GB memory
    disk_size_gb = 10

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  initial_node_count = 1
}

output "kubernetes_cluster_endpoint" {
  value = google_container_cluster.kubernetes_cluster.endpoint
}

output "kubernetes_cluster_ca_certificate" {
  value = base64decode(google_container_cluster.kubernetes_cluster.master_auth.0.cluster_ca_certificate)
}
