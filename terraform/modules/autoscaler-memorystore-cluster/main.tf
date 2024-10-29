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
    module_name = "cloud-solutions/memorystore-cluster-autoscaler-deploy-cluster-v1.0"
  }
}

resource "google_redis_cluster" "memorystore_cluster" {
  count       = var.terraform_memorystore_cluster ? 1 : 0
  name        = var.memorystore_cluster_name
  shard_count = var.memorystore_shard_count
  psc_configs {
    network = var.network
  }
  region                  = var.region
  replica_count           = var.memorystore_replica_count
  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"
  authorization_mode      = "AUTH_MODE_DISABLED"

  zone_distribution_config {
    mode = "MULTI_ZONE"
  }

  deletion_protection_enabled = false

  lifecycle {
    ignore_changes = [shard_count, replica_count]
  }
}

resource "random_id" "role_suffix" {
  byte_length = 4
}

# Limited role for Poller
resource "google_project_iam_custom_role" "metrics_viewer_iam_role" {
  project     = var.project_id
  role_id     = "memorystoreClusterAutoscalerMetricsViewer_${random_id.role_suffix.hex}"
  title       = "Memorystore Cluster Autoscaler Metrics Viewer Role"
  description = "Allows a principal to get Memorystore Cluster instances and view time series metrics"
  permissions = [
    "redis.clusters.list",
    "redis.clusters.get",
    "monitoring.timeSeries.list"
  ]
}

# Assign custom role to Poller
resource "google_project_iam_member" "poller_metrics_viewer_iam" {
  role    = google_project_iam_custom_role.metrics_viewer_iam_role.name
  project = var.project_id
  member  = "serviceAccount:${var.poller_sa_email}"
}

# Limited role for Scaler
resource "google_project_iam_custom_role" "capacity_manager_iam_role" {
  project     = var.project_id
  role_id     = "memorystoreClusterAutoscalerCapacityManager_${random_id.role_suffix.hex}"
  title       = "Memorystore Cluster Autoscaler Capacity Manager Role"
  description = "Allows a principal to scale Memorystore Cluster instances"
  permissions = [
    "redis.clusters.get",
    "redis.clusters.update",
    "redis.operations.get"
  ]
}

# Assign custom role to Scaler
resource "google_project_iam_member" "scaler_update_capacity_iam" {
  role    = google_project_iam_custom_role.capacity_manager_iam_role.name
  project = var.project_id
  member  = "serviceAccount:${var.scaler_sa_email}"
}

resource "google_dns_record_set" "memorystore_cluster" {
  count = var.terraform_memorystore_cluster ? 1 : 0
  name  = "cluster.${var.dns_zone.dns_name}"
  type  = "A"
  ttl   = 300

  managed_zone = var.dns_zone.name

  rrdatas = [one(google_redis_cluster.memorystore_cluster).discovery_endpoints[0].address]
}
