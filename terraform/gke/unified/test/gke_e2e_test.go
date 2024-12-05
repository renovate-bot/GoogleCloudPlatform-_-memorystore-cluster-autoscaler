//go:build e2e

/**
 * Copyright 2024 Google LLC
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
 * limitations under the License.
 */

package test

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"testing"
	"time"
	"strconv"

	cluster "cloud.google.com/go/redis/cluster/apiv1"
	clusterpb "cloud.google.com/go/redis/cluster/apiv1/clusterpb"

	logger "github.com/gruntwork-io/terratest/modules/logger"
	retry "github.com/gruntwork-io/terratest/modules/retry"
	terraform "github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	envconfig "github.com/sethvargo/go-envconfig"
	assert "github.com/stretchr/testify/assert"
)

type TestConfig struct {
	ProjectId string `env:"PROJECT_ID,required"`
	Region    string `env:"REGION,required"`
}

func waitForMemorystoreClusterShards(t *testing.T, clusterClient *cluster.CloudRedisClusterClient, clusterId string, targetShards int32, retries int, sleepBetweenRetries time.Duration) error {

	ctx := context.Background()
	maxWaitTime := time.Duration(retries) * sleepBetweenRetries
	status := fmt.Sprintf("Waiting for up to %.0f seconds for cluster to reach %d shards...", maxWaitTime.Seconds(), targetShards)

	message, err := retry.DoWithRetryE(
		t,
		status,
		retries,
		sleepBetweenRetries,
		func() (string, error) {
			clusterReq := &clusterpb.GetClusterRequest{
				Name: clusterId,
			}
			cluster, err := clusterClient.GetCluster(ctx, clusterReq)
			assert.Nil(t, err)
			assert.NotNil(t, cluster)
			shards := cluster.GetShardCount()
			if shards != targetShards {
				return "", fmt.Errorf("currently %d shards", shards)
			}
			return "Memorystore cluster reached target size", nil
		},
	)
	logger.Log(t, message)
	return err
}

func deployAutoscaler(t *testing.T, projectId string, region string, targetShards int32) error {

	deployScript := "./gke_deploy.sh"
	deployArgs := []string{
		deployScript,
		projectId,
		region,
		strconv.Itoa(int(targetShards)),
	}

	cmd := &exec.Cmd{
		Path:   deployScript,
		Args:   deployArgs,
		Stdout: os.Stdout,
		Stderr: os.Stderr,
	}

	logger.Log(t, "Executing deploy script with args:", cmd)

	err := cmd.Start()
	if err != nil {
		logger.Log(t, "There was an error starting the deploy script:")
		logger.Log(t, err)
		return err
	}

	err = cmd.Wait()
	if err != nil {
		logger.Log(t, "There was an error waiting for the deploy script:")
		logger.Log(t, err)
		return err
	}

	return nil
}

func TestGkeEndToEndDeployment(t *testing.T) {

	const (
		clusterName           = "autoscaler-target-memorystore-cluster"
		clusterStartingShards = 1
		clusterTargetShards   = 3
	)

	var config TestConfig

	ctx := context.Background()
	err := envconfig.Process(ctx, &config)
	if err != nil {
		logger.Log(t, "There was an error processing the supplied environment variables:")
		logger.Log(t, err)
		t.Fatal()
	}

	terraformDir := "../"

	test_structure.RunTestStage(t, "setup", func() {
		terraformOptions := &terraform.Options{
			TerraformDir: terraformDir,
			Vars: map[string]interface{}{
				"project_id":               config.ProjectId,
				"region":                   config.Region,
				"memorystore_cluster_name": clusterName,
				"memorystore_shard_count":  clusterStartingShards,
				"terraform_spanner_state":  "true",
			},
			NoColor: true,
		}

		test_structure.SaveTerraformOptions(t, terraformDir, terraformOptions)
		terraform.Init(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "teardown", func() {
		logger.Log(t, "TEST STAGE: TEARDOWN")
		logger.Log(t, "----------------------------------------------------------")
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.Destroy(t, terraformOptions)
		logger.Log(t, "----------------------------------------------------------")
		logger.Log(t, "TEST STAGE: TEARDOWN COMPLETED")
	})

	test_structure.RunTestStage(t, "apply", func() {
		logger.Log(t, "TEST STAGE: TERRAFORM APPLY")
		logger.Log(t, "----------------------------------------------------------")
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.ApplyAndIdempotent(t, terraformOptions)
		logger.Log(t, "----------------------------------------------------------")
		logger.Log(t, "TEST STAGE: TERRAFORM APPLY COMPLETED")

	})

	test_structure.RunTestStage(t, "validate", func() {
		logger.Log(t, "TEST STAGE: VALIDATE")
		logger.Log(t, "----------------------------------------------------------")

		// Retries and sleep duration for a total maximum of 15 minutes timeout per operation
		const retries = 30
		const sleepBetweenRetries = time.Second * 30

		ctx := context.Background()

		clusterClient, err := cluster.NewCloudRedisClusterClient(ctx)
		assert.Nil(t, err)
		assert.NotNil(t, clusterClient)
		defer clusterClient.Close()

		clusterId := fmt.Sprintf("projects/%s/locations/%s/clusters/%s", config.ProjectId, config.Region, clusterName)

		assert.Nil(t, waitForMemorystoreClusterShards(t, clusterClient, clusterId, clusterStartingShards, retries, sleepBetweenRetries))
		assert.Nil(t, deployAutoscaler(t, config.ProjectId, config.Region, clusterTargetShards))
		assert.Nil(t, waitForMemorystoreClusterShards(t, clusterClient, clusterId, clusterTargetShards, retries, sleepBetweenRetries))

		logger.Log(t, "----------------------------------------------------------")
		logger.Log(t, "TEST STAGE: VALIDATE COMPLETED")
	})
}
