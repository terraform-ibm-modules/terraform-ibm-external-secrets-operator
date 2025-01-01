// Tests in this file are run in the PR pipeline
package test

import (
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Resource groups are maintained https://github.ibm.com/GoldenEye/ge-dev-account-management
const resourceGroup = "geretain-test-ext-secrets-sync"
const basicExampleTerraformDir = "examples/basic"

type Config struct {
	SmGuid   string `yaml:"secretsManagerGuid"`
	SmRegion string `yaml:"secretsManagerRegion"`

	// secret ids for the secrets composing the imported certificate to create
	ImpCertIntermediateSecretId string `yaml:"imported_certificate_intermediate_secret_id"`
	ImpCertPublicSecretId       string `yaml:"imported_certificate_public_secret_id"`
	ImpCertPrivateSecretId      string `yaml:"imported_certificate_private_secret_id"`
	ImpCertificateSmGuid        string `yaml:"imported_certificate_sm_id"`
	ImpCertificateSmRegion      string `yaml:"imported_certificate_sm_region"`

	// acme private apikey references for CA
	AcmeLEPrivateKeySmGuid   string `yaml:"acme_letsencrypt_private_key_sm_id"`
	AcmeLEPrivateKeySmRegion string `yaml:"acme_letsencrypt_private_key_sm_region"`
	AcmeLEPrivateKeySecretId string `yaml:"acme_letsencrypt_private_key_secret_id"`

	// sDNLB serviceID
	SdnlbServiceidName string `yaml:"sdnlbServiceIdName"`
}

var smGuid string
var smRegion string

var ignoreUpdates = []string{
	"module.es_kubernetes_secret_usr_pass.helm_release.external_secrets_operator[0]",
	"module.es_kubernetes_secret_arbitrary_cloudant.helm_release.external_secrets_operator[0]",
	"module.es_kubernetes_secret_arbitrary_cr_registry.helm_release.external_secrets_operator[0]",
	"module.es_kubernetes_secret_image_pull.helm_release.external_secrets_operator[0]",
	"module.external_secrets_operator.helm_release.external_secrets_operator",
	"module.external_secrets_operator.helm_release.pod_reloader[0]",
	"module.external_secret_arbitrary_cloudant.helm_release.kubernetes_secret[0]",
	"module.external_secret_tp_multisg_2.helm_release.kubernetes_secret[0]",
	"module.external_secret_imported_certificate[0].helm_release.kubernetes_secret_certificate[0]",
	"module.external_secret_tp[0].helm_release.kubernetes_secret[0]",
	"module.external_secret_private_certificate.helm_release.kubernetes_secret_certificate[0]",
	"module.external_secret_kv_multiplekeys.helm_release.kubernetes_secret_kv_all[0]",
	"module.external_secret_arbitrary_cr_registry.helm_release.kubernetes_secret[0]",
	"module.external_secret_secret_image_pull.helm_release.kubernetes_secret[0]",
	"module.external_secret_public_certificate[0].helm_release.kubernetes_secret_certificate[0]",
	"module.external_secret_kv_singlekey.helm_release.kubernetes_secret_kv_key[0]",
	"module.external_secret_tp[1].helm_release.kubernetes_secret[0]",
	"module.external_secret_tp_multisg_1.helm_release.kubernetes_secret[0]",
	"module.external_secret_usr_pass.helm_release.kubernetes_secret_user_pw[0]",
	"module.external_secret_tp_nosg.helm_release.kubernetes_secret[0]",
	"module.sdnlb_eso_secret.helm_release.sdnlb_external_secret",
}

func setupOptions(t *testing.T, prefix string, terraformDir string, terraformVars map[string]interface{}) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  terraformDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		TerraformVars: terraformVars,

		IgnoreUpdates: testhelper.Exemptions{
			List: ignoreUpdates,
		},
		ImplicitDestroy: []string{
			// workaround for the issue https://github.ibm.com/GoldenEye/issues/issues/10743
			// when the issue is fixed on IKS, so the destruction of default workers pool is correctly managed on provider/clusters service the next two entries should be removed
			"'module.ocp_base.ibm_container_vpc_worker_pool.autoscaling_pool[\"default\"]'",
			"'module.ocp_base.ibm_container_vpc_worker_pool.pool[\"default\"]'",
		},

		IgnoreDestroys: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				// adding resources to ignore for modules version update - to be removed after the merge
				"module.ocp_base.time_sleep.wait_operators",
			},
		},
	})

	return options
}

func TestReloaderOperational(t *testing.T) {
	t.Parallel()
	// terraform vars for reloader test
	reloaderTerraformVars := map[string]interface{}{}

	reloaderTerraformVars["existing_sm_instance_guid"] = smGuid
	reloaderTerraformVars["existing_sm_instance_region"] = smRegion

	options := setupOptions(t, "reloader", basicExampleTerraformDir, reloaderTerraformVars)

	options.SkipTestTearDown = true
	defer func() {
		options.TestTearDown()
	}()

	_, err := options.RunTestConsistency()
	if assert.Nil(t, err, "Consistency test should not have errored") {
		outputs := options.LastTestTerraformOutputs
		_, tfOutputsErr := testhelper.ValidateTerraformOutputs(outputs, "cluster_id")
		if assert.Nil(t, tfOutputsErr, tfOutputsErr) {

			// get cluster config
			cloudinfosvc, err := cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{})
			if assert.Nil(t, err, "Error creating cloud info service") {
				clusterConfigPath, err := cloudinfosvc.GetClusterConfigConfigPath(outputs["cluster_id"].(string))
				defer func() {
					// attempt to remove cluster config file after test
					_ = os.Remove(clusterConfigPath)
				}()
				if assert.Nil(t, err, "Error getting cluster config path") {
					sampleApp := "./samples/sample.yaml"
					deploymentName := "example-deployment"
					namespace := "reloader-test-ns"
					containerName := "busybox-container"
					secretName := "example-secret"
					secretValue := "top-secret"
					updatedSecret := "./samples/updated_secret.yaml" // pragma: allowlist secret
					updatedSecretValue := "updated-secret"

					sleepBetweenRetries := 20 * time.Second
					// configure Terratest with cluster config
					ocOptions := k8s.NewKubectlOptions("", clusterConfigPath, namespace)
					// deploy sample app
					applyError := k8s.KubectlApplyE(t, ocOptions, sampleApp)
					if assert.Nil(t, applyError, "Error applying sample app") {
						// confirm app is running
						k8s.WaitUntilDeploymentAvailable(t, ocOptions, deploymentName, 20, sleepBetweenRetries)
						k8s.WaitUntilSecretAvailable(t, ocOptions, secretName, 20, sleepBetweenRetries)
						// Check that the secret value is correct
						// Get pod name from deployment
						pods, err := GetPodNamesFromDeployment(t, ocOptions, deploymentName)
						if assert.Nil(t, err, "Error getting pod names") {
							initialPod := k8s.GetPod(t, ocOptions, pods[0])
							k8s.WaitUntilPodAvailable(t, ocOptions, initialPod.Name, 20, sleepBetweenRetries)
							logs := k8s.GetPodLogs(t, ocOptions, initialPod, containerName)
							if assert.Contains(t, logs, secretValue, "Initial Secret value not found in logs") {
								t.Log("Initial secret value found in logs")
								t.Log(logs)
							}
							// update secret with updated secret
							applyError = k8s.KubectlApplyE(t, ocOptions, updatedSecret)
							if assert.Nil(t, applyError, "Error applying updated secret") {
								// Set a timeout duration
								timeout := 20 * time.Second

								// Create a channel to signal the end of the timeout
								timeoutChan := time.After(timeout)
								var newPodName string
								failed := false
								// Loop until a new initialPod is found or until timeout
								// Using a label on the for loop allows us to break out of the loop, otherwise the break would only break out of the select statement
							Loop:
								for {
									select {
									case <-timeoutChan:
										// Handle the timeout case
										assert.Fail(t, "timeout reached while waiting for initialPod to change")
										failed = true
										break Loop
									default:
										// Sleep to avoid busy waiting
										time.Sleep(time.Second)

										// Update initialPod names
										currentPods, err := GetPodNamesFromDeployment(t, ocOptions, deploymentName)
										if err != nil {
											t.Log("Error getting initialPod names")
											break
										}

										for _, pod := range currentPods {
											if !common.StrArrayContains(pods, pod) {
												newPodName = pod
												break Loop
											}
										}

										if newPodName != "" {
											break
										}
									}
								}
								if !failed {
									k8s.WaitUntilDeploymentAvailable(t, ocOptions, deploymentName, 20, sleepBetweenRetries)
									newPod := k8s.GetPod(t, ocOptions, newPodName)
									k8s.WaitUntilPodAvailable(t, ocOptions, newPod.Name, 20, sleepBetweenRetries)
									// confirm app restarted and picked up new secret by checking logs
									newLogs := k8s.GetPodLogs(t, ocOptions, newPod, containerName)
									if assert.Contains(t, newLogs, updatedSecretValue, "Updated Secret value not found in logs") {
										t.Log("Updated secret value found in logs")
										t.Log(newLogs)
									}
								}
							}
						}
					}
				}
			}

		}
	}
}

func GetPodNamesFromDeployment(t *testing.T, options *k8s.KubectlOptions, deploymentName string) ([]string, error) {
	// Get the deployment object
	deployment, err := k8s.GetDeploymentE(t, options, deploymentName)
	if err != nil {
		return nil, err
	}

	// Construct the label selector from the deployment
	labelSelector := metav1.FormatLabelSelector(deployment.Spec.Selector)

	// List Pods using label selector
	pods, err := k8s.ListPodsE(t, options, metav1.ListOptions{LabelSelector: labelSelector})
	if err != nil {
		return nil, err
	}

	// Extract the pod names
	var podNames []string
	for _, pod := range pods {
		podNames = append(podNames, pod.Name)
	}

	return podNames, nil
}
