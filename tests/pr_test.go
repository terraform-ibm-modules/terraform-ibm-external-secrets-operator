// Tests in this file are run in the PR pipeline
package test

import (
	"log"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"gopkg.in/yaml.v3"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const resourceGroup = "geretain-test-ext-secrets-sync"
const defaultExampleTerraformDir = "examples/all-combined"
const basicExampleTerraformDir = "examples/basic"

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

type Config struct {
	SmGuid   string `yaml:"secretsManagerGuid"`
	SmCRN    string `yaml:"secretsManagerCRN"`
	SmRegion string `yaml:"secretsManagerRegion"`
	RgId     string `yaml:"resourceGroupTestPermanentId"`
	CisName  string `yaml:"cisInstanceName"`

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
}

var smGuid string
var smCRN string
var smRegion string
var rgId string
var cisName string
var impCertificateSmRegion string
var impCertificateSmGuid string
var impCertIntermediateSecretID string
var impCertPublicSecretID string
var impCertPrivateSecretID string
var acmeLEPrivateKeySmGuid string
var acmeLEPrivateKeySmRegion string
var acmeLEPrivateKeySecretId string

// terraform vars for all-combined test (including Upgrade one)
var allCombinedTerraformVars map[string]interface{}

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	// Read the YAML file contents
	data, err := os.ReadFile(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}
	// Create a struct to hold the YAML data
	var config Config
	// Unmarshal the YAML data into the struct
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		log.Fatal(err)
	}

	// Parse the SM guid and region from data and setting all-combined test input values used in TestRunDefaultExample and TestRunUpgradeExample
	smGuid = config.SmGuid
	smCRN = config.SmCRN
	smRegion = config.SmRegion
	cisName = config.CisName
	rgId = config.RgId
	impCertIntermediateSecretID = config.ImpCertIntermediateSecretId
	impCertPrivateSecretID = config.ImpCertPrivateSecretId
	impCertPublicSecretID = config.ImpCertPublicSecretId
	acmeLEPrivateKeySmGuid = config.AcmeLEPrivateKeySmGuid
	acmeLEPrivateKeySmRegion = config.AcmeLEPrivateKeySmRegion
	acmeLEPrivateKeySecretId = config.AcmeLEPrivateKeySecretId
	impCertificateSmGuid = config.ImpCertificateSmGuid
	impCertificateSmRegion = config.ImpCertificateSmRegion

	allCombinedTerraformVars = map[string]interface{}{
		"existing_cis_instance_name":              cisName,
		"existing_cis_instance_resource_group_id": rgId,
		// imported certificate and public certificate creation management
		"existing_sm_instance_crn":                    smCRN,
		"existing_sm_instance_guid":                   smGuid,
		"existing_sm_instance_region":                 smRegion,
		"imported_certificate_sm_region":              impCertificateSmRegion,
		"imported_certificate_sm_id":                  impCertificateSmGuid,
		"imported_certificate_intermediate_secret_id": impCertIntermediateSecretID,
		"imported_certificate_public_secret_id":       impCertPublicSecretID,
		"imported_certificate_private_secret_id":      impCertPrivateSecretID,
		"acme_letsencrypt_private_key_secret_id":      acmeLEPrivateKeySecretId,
		"acme_letsencrypt_private_key_sm_id":          acmeLEPrivateKeySmGuid,
		"acme_letsencrypt_private_key_sm_region":      acmeLEPrivateKeySmRegion,
		// setting skip_iam_authorization_policy to true because using the existing secrets manager instance and the policy already exists
		"skip_iam_authorization_policy": true,
		"service_endpoints":             "public",
	}

	os.Exit(m.Run())
}

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

		IgnoreDestroys: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				// adding resources to ignore for modules version update - to be removed after the merge
				"module.ocp_base.time_sleep.wait_operators",
			},
		},
	})

	return options
}

func TestRunDefaultExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "eso", defaultExampleTerraformDir, allCombinedTerraformVars)

	options.SkipTestTearDown = true
	defer func() {
		options.TestTearDown()
	}()
	output, err := options.RunTestConsistency()

	if assert.Nil(t, err, "Consistency test should not have errored") {
		outputs := options.LastTestTerraformOutputs
		_, tfOutputsErr := testhelper.ValidateTerraformOutputs(outputs, "cluster_id")
		if assert.Nil(t, tfOutputsErr, tfOutputsErr) {
			log.Println("Prefix used " + options.Prefix)

			clusterId := outputs["cluster_id"].(string)

			log.Println("clusterId " + clusterId)

			// building the list of secrets to test
			namespaces_for_apikey_login := []string{"apikeynspace1", "apikeynspace2", "apikeynspace3", "apikeynspace4"}
			namespaces_for_tp_login := []string{"tpnspace1", "tpnspace2"}

			secretsMap := map[string]string{
				"dockerconfigjson-uc": namespaces_for_apikey_login[0],
				// temporary disabled cloudant resource key secret test
				"dockerconfigjson-arb":                         namespaces_for_apikey_login[2],
				"pvtcertificate-tls":                           namespaces_for_apikey_login[2],
				"kv-single-key":                                namespaces_for_apikey_login[3],
				"kv-multiple-keys":                             namespaces_for_apikey_login[3],
				"dockerconfigjson-iam":                         namespaces_for_apikey_login[3],
				"dockerconfigjson-chain":                       namespaces_for_apikey_login[3],
				options.Prefix + "-arbitrary-arb-tp-0":         namespaces_for_tp_login[0],
				options.Prefix + "-arbitrary-arb-tp-1":         namespaces_for_tp_login[1],
				options.Prefix + "-arbitrary-arb-tp-multisg-1": "tpns-multisg",
				options.Prefix + "-arbitrary-arb-tp-multisg-2": "tpns-multisg",
				options.Prefix + "-arbitrary-arb-tp-nosg":      "tpns-nosg",
				options.Prefix + "-arbitrary-arb-cstore-tp":    "eso-cstore-tp-namespace",
			}

			log.Printf("secretsMap %s", secretsMap)

			// get cluster config
			log.Println("Loading cluster configuration with id " + clusterId)
			cloudinfosvc, err := cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{})
			if assert.Nil(t, err, "Error creating cloud info service") {
				clusterConfigPath, err := cloudinfosvc.GetClusterConfigConfigPath(clusterId)
				defer func() {
					// attempt to remove cluster config file after test
					_ = os.Remove(clusterConfigPath)
				}()
				if assert.Nil(t, err, "Error getting cluster config path") {
					// for each secret to test configure Terratest with cluster config
					// the test checks if each secret is correctly created in the cluster
					for secretName, secretNamespace := range secretsMap {
						ocOptions := k8s.NewKubectlOptions("", clusterConfigPath, secretNamespace)
						log.Printf("Testing secret name %s namespace %s\n", secretName, secretNamespace)
						_, err := k8s.GetSecretE(t, ocOptions, secretName)
						assert.Nil(t, err, "Error retrieving secret "+secretName+" in namespace "+secretNamespace)
					}
				}
			}
		}
	}

	assert.NotNil(t, output, "Expected some output")
}

func TestRunUpgradeExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "eso-upg", defaultExampleTerraformDir, allCombinedTerraformVars)
	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
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
