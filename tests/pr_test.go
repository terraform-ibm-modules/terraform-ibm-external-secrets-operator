// Tests in this file are run in the PR pipeline
package test

import (
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
	"gopkg.in/yaml.v3"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const resourceGroup = "geretain-test-ext-secrets-sync"
const defaultExampleTerraformDir = "examples/all-combined"
const basicExampleTerraformDir = "examples/basic"

// schematics DA consts
const fullConfigSolutionDir = "solutions/fully-configurable"
const existingResourcesTerraformDir = "tests/existing-resources"

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
		// setting CIS domain to be used in the test
		"pvt_cert_common_name":    "goldeneye.dev.cloud.ibm.com",
		"pvt_root_ca_common_name": "goldeneye.dev.cloud.ibm.com",
		"cert_common_name":        "goldeneye.dev.cloud.ibm.com",
	}

	os.Exit(m.Run())
}

// Note for the test maintainers
// The test leverages on a set of secrets existing on IBM Cloud Secrets Manager instance to pull
// the secrets values and to configure them through External Secrets operator: the secrets for the imported certificate whose
// - public certificate component is stored in `geretain-eso-test-importedcert-public-certificate`
// - intermediate certificate component is stored in `geretain-eso-test-importedcert-intermediate-certificate`
// - private key is stored in `geretain-eso-test-importedcert-private-key`
// expire periodically: in such a case the new values to populate these secrets can be retrieved from the secret named `geretain-eso-public-certificate-for-imported-ones`
// which is a public certificate generated for a test CN and contains the three different components whose value can be used to rotate the expired certificates
// mentioned above. It is configured to be automatically rotated by Secrets Manager so its values are always up to date.

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
	// ignoring updates on trusted_profile due to issue https://github.com/IBM-Cloud/terraform-provider-ibm/issues/6050
	// the issue is a workaround for update on trusted_profile resource history field
	// to remove when solved
	"module.external_secrets_trusted_profiles[0].ibm_iam_trusted_profile.trusted_profile",
	"module.external_secrets_trusted_profiles[1].ibm_iam_trusted_profile.trusted_profile",
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
	_, err := options.RunTestConsistency()

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
					// check Reloader is installed with the correct image and version
					// assert reloader image
					// get the image and version from the variables.tf in options.TerraformDir
					// read the file
					variablesFile := options.TerraformDir + "/variables.tf"
					data, err := os.ReadFile(variablesFile)
					if assert.Nil(t, err, "Error reading variables file") {
						// parse the file
						lines := strings.Split(string(data), "\n")
						// find the line with the reloader image
						var reloaderImage string
						var reloaderVersion string

						// Get values from TerraformVars if provided
						if options.TerraformVars["reloader_image"] != nil {
							reloaderImage = options.TerraformVars["reloader_image"].(string)
						} else {
							// Check for both  reloader_image variables
							reloaderImage = extractDefaultValueFromFile(lines, "reloader_image")

							// If still not found, check the root variables.tf file
							if reloaderImage == "" {
								rootVariablesPath := filepath.Join(options.TerraformDir, "..", "..", "variables.tf")
								if rootData, err := os.ReadFile(rootVariablesPath); err == nil {
									rootLines := strings.Split(string(rootData), "\n")
									reloaderImage = extractDefaultValueFromFile(rootLines, "reloader_image")
								}
							}
						}

						if options.TerraformVars["reloader_image_version"] != nil {
							reloaderVersion = options.TerraformVars["reloader_image_version"].(string)
						} else {
							// Find the line with the reloader version
							reloaderVersion = extractDefaultValueFromFile(lines, "reloader_image_version")
							// If not found, check the root variables.tf file
							if reloaderVersion == "" {
								rootVariablesPath := filepath.Join(options.TerraformDir, "..", "..", "variables.tf")
								if rootData, err := os.ReadFile(rootVariablesPath); err == nil {
									rootLines := strings.Split(string(rootData), "\n")
									reloaderVersion = extractDefaultValueFromFile(rootLines, "reloader_image_version")
								}
							}
						}

						// Check the image and version
						// Get reloader pods - use the correct labels and namespace
						esoNamespace := "apikeynspace1" // staticly set in locals of basic example

						// assert all values are set
						if !assert.NotEmpty(t, reloaderImage, "Reloader image is empty") {
							t.Log("FAILURE: Reloader image is empty - could not find value in variables")
						}

						if !assert.NotEmpty(t, reloaderVersion, "Reloader version is empty") {
							t.Log("FAILURE: Reloader version is empty - could not find value in variables")
						}

						// Get the reloader pods
						reloaderPods, err := k8s.ListPodsE(t, k8s.NewKubectlOptions("", clusterConfigPath, esoNamespace), metav1.ListOptions{
							LabelSelector: "provider=stakater,group=com.stakater.platform",
						})
						if assert.Nil(t, err, "Error getting reloader pods") {
							if assert.GreaterOrEqual(t, len(reloaderPods), 1, "Expected at least one reloader pod") {
								reloaderPod := reloaderPods[0]
								// Check the image of the reloader pod
								actualImage := reloaderPod.Spec.Containers[0].Image
								expectedImage := reloaderImage + ":" + reloaderVersion
								if !assert.Equal(t, expectedImage, actualImage, "Reloader image does not match expected image") {
									t.Logf("FAILURE: Reloader image does not match expected image. Expected: %s, Actual: %s", expectedImage, actualImage)
								}
							}
						}
					}

					// test reloader functionality
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
											// Use the labeled break to exit the outer loop
											continue Loop
										}

										for _, pod := range currentPods {
											if !common.StrArrayContains(pods, pod) {
												newPodName = pod
												break Loop
											}
										}

										if newPodName != "" {
											break Loop
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

// Helper function to extract default value from terraform variable definitions
func extractDefaultValueFromFile(lines []string, variableName string) string {
	inTargetVariable := false
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "variable") && strings.Contains(line, "\""+variableName+"\"") {
			inTargetVariable = true
			continue
		}

		// We're in the target variable block, look for the default value
		if inTargetVariable {
			if strings.HasPrefix(line, "default") {
				// Extract the value between = and either # or end of line
				parts := strings.Split(line, "=")
				if len(parts) > 1 {
					value := strings.TrimSpace(parts[1])

					// Remove trailing comment if exists
					if strings.Contains(value, "#") {
						value = strings.Split(value, "#")[0]
						value = strings.TrimSpace(value)
					}

					// Handle quoted strings properly
					if strings.HasPrefix(value, "\"") {
						// Extract the string using proper quote handling
						// This handles any content in quotes, even if it contains special characters
						re := regexp.MustCompile(`"((?:\\"|[^"])*)"`)
						matches := re.FindStringSubmatch(value)
						if len(matches) >= 2 {
							// Get the content inside the quotes and unescape any quotes
							value = strings.ReplaceAll(matches[1], "\\\"", "\"")
						} else {
							// Fallback to simple trim if regex didn't work
							value = strings.Trim(value, "\"")
						}
					}

					// Remove trailing spaces or commas
					value = strings.TrimRight(value, " ,")
					return value
				}
			}

			// If we hit a closing brace, we've exited the variable block
			if line == "}" {
				inTargetVariable = false
			}
		}
	}
	return ""
}

// Schematics DA test

func setupOptionsSchematics(t *testing.T, prefix string, dir string) *testhelper.TestOptions {
	// Verify ibmcloud_api_key variable is set
	checkVariable := "TF_VAR_ibmcloud_api_key"
	val, present := os.LookupEnv(checkVariable)
	require.True(t, present, checkVariable+" environment variable not set")
	require.NotEqual(t, "", val, checkVariable+" environment variable is empty")

	logger.Log(t, "variable "+checkVariable+" correctly set")

	// Verify region variable is set, otherwise it computes it
	region := ""
	checkRegion := "TF_VAR_region"
	valRegion, presentRegion := os.LookupEnv(checkRegion)
	if presentRegion {
		region = valRegion
	} else {
		// Programmatically determine region to use based on availability
		region, _ = testhelper.GetBestVpcRegion(val, "../common-dev-assets/common-go-assets/cloudinfo-region-vpc-gen2-prefs.yaml", "eu-de")
	}

	logger.Log(t, "Using region: ", region)

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:      t,
		TerraformDir: dir,
		Prefix:       prefix,
		IgnoreUpdates: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				// "time_sleep.sleep_time",
			},
		},
		Region:        region,
		ResourceGroup: resourceGroup,
	})
	return options
}

// sets up options for solutions through schematics
func setupSolutionSchematicOptions(t *testing.T, prefix string, dir string) *testschematic.TestSchematicOptions {

	logger.Log(t, "setupSolutionSchematicOptions - Using prefix: ", prefix)

	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
		TarIncludePatterns: []string{
			"*.tf",
			"chart/*.yaml",
			"chart/raw/*.yaml",
			"chart/raw/templates/*.yaml",
			"chart/raw/templates/*.tpl",
			"modules/eso-clusterstore/*.tf",
			"modules/eso-secretstore/*.tf",
			"modules/eso-trusted-profile/*.tf",
			"modules/eso-external-secret/*.tf",
			dir + "/*.tf",
		},
		TemplateFolder:         dir,
		Tags:                   []string{"test-esoda-schematic"},
		Prefix:                 prefix,
		DeleteWorkspaceOnFail:  false,
		WaitJobCompleteMinutes: 60,
	})

	return options
}

// helper function to set up inputs for full config solution test, will help keep it consistent
// between normal and upgrade tests
func getFullConfigSolutionTestVariables(mainOptions *testschematic.TestSchematicOptions, existingOptions *testhelper.TestOptions) []testschematic.TestSchematicTerraformVar {

	eso_secretsstores_configuration := map[string]any{
		"cluster_secrets_stores": map[string]any{

			"css-1": map[string]any{
				"namespace":                              "eso-namespace-cs1",
				"create_namespace":                       true,
				"existing_serviceid_id":                  "",
				"serviceid_name":                         "esoda-test-css-1-serviceid",
				"serviceid_description":                  "esoda-test-css-1-serviceid description",
				"existing_account_secrets_group_id":      "",
				"account_secrets_group_name":             "esoda-test-cs-accsg-1",
				"account_secrets_group_description":      "esoda-test-cs-accsg-1 description",
				"trusted_profile_name":                   "",
				"trusted_profile_description":            "",
				"existing_service_secrets_group_id_list": []string{},
				"service_secrets_groups_list": []map[string]any{
					{
						"name":        "esoda-test-cs-s1-sg",
						"description": "Secrets group 1 for secrets used by the ESO",
					},
					{
						"name":        "esoda-test-cs-s2-sg",
						"description": "Secrets group 2 for secrets used by the ESO",
					},
				},
			},
			"css-2": map[string]any{
				"namespace":                              "eso-namespace-cs2",
				"create_namespace":                       true,
				"existing_serviceid_id":                  "",
				"serviceid_name":                         "esoda-test-css-3-serviceid",
				"serviceid_description":                  "esoda-test-css-3-serviceid description",
				"existing_account_secrets_group_id":      "",
				"account_secrets_group_name":             "esoda-test-cs-accsg-3",
				"account_secrets_group_description":      "esoda-test-cs-accsg-3 description",
				"trusted_profile_name":                   "",
				"trusted_profile_description":            "",
				"existing_service_secrets_group_id_list": []string{},
				"service_secrets_groups_list": []map[string]any{
					{
						"name":        "esoda-test-cs-s3-sg",
						"description": "Secrets group 3 for secrets used by the ESO",
					},
					{
						"name":        "esoda-test-cs-s4-sg",
						"description": "Secrets group 4 for secrets used by the ESO",
					},
				},
			},
		},
		"secrets_stores": map[string]any{

			"ss-1": map[string]any{
				"namespace":                              "eso-namespace-ss1",
				"create_namespace":                       true,
				"existing_serviceid_id":                  "",
				"serviceid_name":                         "esoda-test-ss-1-serviceid",
				"serviceid_description":                  "esoda-test-ss-1-serviceid description",
				"existing_account_secrets_group_id":      "",
				"account_secrets_group_name":             "esoda-test-ss-accsg-1",
				"account_secrets_group_description":      "esoda-test-ss-accsg-1 description",
				"trusted_profile_name":                   "",
				"trusted_profile_description":            "",
				"existing_service_secrets_group_id_list": []string{},
				"service_secrets_groups_list": []map[string]any{
					{
						"name":        "esoda-test-ss-s1-sg",
						"description": "Secrets group 1 for secrets used by the ESO",
					},
					{
						"name":        "esoda-test-ss-s2-sg",
						"description": "Secrets group 2 for secrets used by the ESO",
					},
				},
			},
			"ss-2": map[string]any{
				"namespace":                              "eso-namespace-ss2",
				"create_namespace":                       true,
				"existing_serviceid_id":                  "",
				"serviceid_name":                         "esoda-test-ss-2-serviceid",
				"serviceid_description":                  "esoda-test-ss-2-serviceid description",
				"existing_account_secrets_group_id":      "",
				"account_secrets_group_name":             "esoda-test-ss-accsg-2",
				"account_secrets_group_description":      "esoda-test-ss-accsg-2 description",
				"trusted_profile_name":                   "",
				"trusted_profile_description":            "",
				"existing_service_secrets_group_id_list": []string{},
				"service_secrets_groups_list": []map[string]any{
					{
						"name":        "esoda-test-ss-s3-sg",
						"description": "Secrets group 3 for secrets used by the ESO",
					},
					{
						"name":        "esoda-test-ss-s4-sg",
						"description": "Secrets group 4 for secrets used by the ESO",
					},
				},
			},
		},
	}

	logger.Log(mainOptions.Testing, "setupSolutionSchematicOptions - Using mainOptions.Prefix: ", mainOptions.Prefix)

	// TODO TO REMOVE
	tempClusterCRN := "crn:v1:bluemix:public:containers-kubernetes:us-east:a/abac0df06b644a9cabc6e44f55b3880e:d0gtejpw0a5163f67aig::"

	vars := []testschematic.TestSchematicTerraformVar{
		{Name: "ibmcloud_api_key", Value: mainOptions.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "prefix", Value: mainOptions.Prefix, DataType: "string"},
		{Name: "existing_secrets_manager_crn", Value: smCRN, DataType: "string"},
		// TODO TO UNCOMMENT
		// {Name: "existing_cluster_crn", Value: existingOptions.LastTestTerraformOutputs["cluster_crn"], DataType: "string"},
		// TODO TO REMOVE
		{Name: "existing_cluster_crn", Value: tempClusterCRN, DataType: "string"},
		{Name: "eso_secretsstores_configuration", Value: eso_secretsstores_configuration, DataType: "object"},
	}

	return vars
}

func TestRunFullConfigSolutionSchematics(t *testing.T) {

	// set up the options for existing resource deployment
	// needed by solution
	existingResourceOptions := setupOptionsSchematics(t, "eso-cluster-full", existingResourcesTerraformDir)
	// TODO TO UNCOMMENT
	// Creates temp dirs and runs InitAndApply for existing resources
	// outputs will be in options after apply

	// existingResourceOptions.SkipTestTearDown = true
	// _, existDeployErr := existingResourceOptions.RunTest()
	// defer existingResourceOptions.TestTearDown() // public function ignores skip above

	// // immediately fail and exit test if existing deployment failed (tear down is in a defer)
	// require.NoError(t, existDeployErr, "error creating needed existing VPC resources")

	// start main schematics test
	options := setupSolutionSchematicOptions(t, "eso-full", fullConfigSolutionDir)

	// TODO TO REMOVE
	options.SkipTestTearDown = true

	options.TerraformVars = getFullConfigSolutionTestVariables(options, existingResourceOptions)

	err := options.RunSchematicTest()
	assert.Nil(t, err, "This should not have errored")

}

func TestRunFullConfigSolutionUpgradeSchematics(t *testing.T) {

	// set up the options for existing resource deployment
	// needed by solution
	existingResourceOptions := setupOptionsSchematics(t, "eso-cluster-fupg", existingResourcesTerraformDir)
	// TODO TO UNCOMMENT
	// Creates temp dirs and runs InitAndApply for existing resources
	// outputs will be in options after apply

	// existingResourceOptions.SkipTestTearDown = true
	// _, existDeployErr := existingResourceOptions.RunTest()
	// defer existingResourceOptions.TestTearDown() // public function ignores skip above

	// // immediately fail and exit test if existing deployment failed (tear down is in a defer)
	// require.NoError(t, existDeployErr, "error creating needed existing VPC resources")

	// start main schematics test
	options := setupSolutionSchematicOptions(t, "eso-fupg", fullConfigSolutionDir)

	// TODO TO REMOVE
	options.SkipTestTearDown = true

	options.TerraformVars = getFullConfigSolutionTestVariables(options, existingResourceOptions)

	err := options.RunSchematicUpgradeTest()
	assert.Nil(t, err, "This should not have errored")
}
