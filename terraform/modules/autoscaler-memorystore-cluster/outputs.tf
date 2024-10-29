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

output "memorystore_discovery_endpoint" {
  value       = length(google_redis_cluster.memorystore_cluster) > 0 ? one(google_redis_cluster.memorystore_cluster).discovery_endpoints[0] : null
  description = "Memorystore discovery endpoint (currently single value)"
}
