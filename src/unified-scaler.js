/* Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License
 */

const pollerCore = require('./poller/poller-core');
const scalerCore = require('./scaler/scaler-core');
const {logger} = require('./autoscaler-common/logger');
const yaml = require('js-yaml');
const fs = require('fs/promises');
const CountersBase = require('./autoscaler-common/counters-base');
const {version: packageVersion} = require('../package.json');

/**
 * Startup function for unified poller/scaler
 */
async function main() {
  const DEFAULT_CONFIG_LOCATION =
    '/etc/autoscaler-config/autoscaler-config.yaml';

  logger.info(
    `Autoscaler unified Poller/Scaler v${packageVersion} job started`,
  );

  // This is not a long-running process, but we only want to flush the counters
  // when it has completed. So disable flushing here, and enable and flush in
  // the finally {} block
  CountersBase.setTryFlushEnabled(false);

  let configLocation = DEFAULT_CONFIG_LOCATION;

  /*
   * If set, the AUTOSCALER_CONFIG environment variable is used to
   * retrieve the configuration for this instance of the Poller.
   * Please refer to the documentation in the README.md for GKE
   * deployment for more details.
   */

  if (process.env.AUTOSCALER_CONFIG) {
    configLocation = process.env.AUTOSCALER_CONFIG;
    logger.debug(`Using custom config location ${configLocation}`);
  } else {
    logger.debug(`Using default config location ${configLocation}`);
  }

  try {
    const config = await fs.readFile(configLocation, {encoding: 'utf8'});
    const clusters = await pollerCore.checkMemorystoreClusterScaleMetricsLocal(
      JSON.stringify(yaml.load(config)),
    );
    for (const cluster of clusters) {
      await scalerCore.scaleMemorystoreClusterLocal(cluster);
    }
  } catch (err) {
    logger.error({
      message: 'Error in unified poller/scaler wrapper: ${err}',
      err: err,
    });
  } finally {
    CountersBase.setTryFlushEnabled(true);
    await CountersBase.tryFlush();
  }
}

module.exports = {
  main,
};
