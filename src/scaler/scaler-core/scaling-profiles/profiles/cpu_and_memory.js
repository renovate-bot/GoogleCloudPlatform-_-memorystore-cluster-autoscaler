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

const cpuHighAverageUtilization = require('../rules/cpu/cpu-high-average-utilization.js');
const cpuHighMaximumUtilization = require('../rules/cpu/cpu-high-maximum-utilization.js');
const cpuLowAverageUtilization = require('../rules/cpu/cpu-low-average-utilization.js');
const cpuLowMaximumUtilization = require('../rules/cpu/cpu-low-maximum-utilization.js');

const memoryHighAverageUtilization = require('../rules/memory/memory-high-average-utilization.js');
const memoryHighMaximumUtilization = require('../rules/memory/memory-high-maximum-utilization.js');
const memoryLowAverageUtilization = require('../rules/memory/memory-low-average-utilization.js');
const memoryLowMaximumUtilization = require('../rules/memory/memory-low-maximum-utilization.js');

/**
 * @typedef {import('../../../../autoscaler-common/types.js').RuleSet} RuleSet
 */

/** @type {RuleSet} */
module.exports.ruleSet = {
  cpuHighMaximumUtilization,
  cpuHighAverageUtilization,
  cpuLowMaximumUtilization,
  cpuLowAverageUtilization,
  memoryHighAverageUtilization,
  memoryHighMaximumUtilization,
  memoryLowAverageUtilization,
  memoryLowMaximumUtilization,
};
