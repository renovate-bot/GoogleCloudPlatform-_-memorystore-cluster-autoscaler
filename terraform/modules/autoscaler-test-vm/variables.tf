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

variable "project_id" {
  type        = string
  description = "Project ID where the cluster will run"
}

variable "name" {
  type        = string
  description = "A unique name for the resource"
}

variable "region" {
  type        = string
  description = "The name of the region to run the cluster"
}

variable "network" {
  type        = string
  description = "The subnetwork to host the cluster in"
}

variable "subnetwork" {
  type        = string
  description = "The subnetwork to host the cluster in"
}

variable "machine_type" {
  type        = string
  description = "The machine type to use for the test VM"
  default     = "c3-standard-4"
}

variable "machine_image" {
  type    = string
  default = "debian-cloud/debian-12"
}
