/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

terraform {
  provider_meta "google" {
    module_name = "cloud-solutions/memorystore-cluster-autoscaler-deploy-vm-v1.0"
  }
}

resource "google_service_account" "test_vm_sa" {
  account_id   = "${var.name}-sa"
  display_name = "Memorystore Cluster test VM Instance SA"
}

resource "google_project_iam_member" "test_vm_sa_iam_logging" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.test_vm_sa.email}"
}

data "google_compute_zones" "regional_zones" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "test_vm" {
  project      = var.project_id
  name         = var.name
  machine_type = var.machine_type
  zone         = data.google_compute_zones.regional_zones.names[1]

  boot_disk {
    initialize_params {
      image = var.machine_image
    }
  }

  network_interface {
    subnetwork = var.subnetwork
  }

  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  service_account {
    email  = google_service_account.test_vm_sa.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  allow_stopping_for_update = true
}

resource "google_compute_firewall" "rules" {
  project       = var.project_id
  network       = var.network
  name          = "ssh"
  description   = "Allow SSH from Identity-Aware Proxy"
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
