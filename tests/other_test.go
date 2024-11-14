// Tests in this file are run in the PR pipeline
package test

import (
	"log"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const esoEnrollSMExample = "examples/eso-enroll-into-servicemesh"

func setupOptionsEnrollEso(t *testing.T, prefix string, exampleDir string, implicitDestroy []string, terraformVars map[string]interface{}) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  exampleDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		IgnoreDestroys: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy",
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy_config",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_cse_proxy",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_control_plane",
				"module.ocp_all_inclusive.module.cluster_proxy.null_resource.configure_proxy",
				"module.ocp_all_inclusive.module.ocp_console_patch.null_resource.patch_console_pods",
			},
		},
		IgnoreUpdates: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				"module.service_mesh.helm_release.service_mesh_cse_proxy",
				"module.service_mesh.helm_release.service_mesh_control_plane",
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy",
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy_config",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_cse_proxy",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_control_plane",
				"module.ocp_all_inclusive.module.cluster_proxy.null_resource.configure_proxy",
				"module.ocp_all_inclusive.module.ocp_console_patch.null_resource.patch_console_pods",
			},
		},
		TerraformVars:    terraformVars,
		ImplicitDestroy:  implicitDestroy,
		ImplicitRequired: false,
	})

	return options
}

func TestRunEnrollESOServiceMeshExample(t *testing.T) {
	t.Parallel()

	terraformVars := map[string]interface{}{}
	// deploying eso on default node
	terraformVars["eso_deployment_nodes_configuration"] = "private"
	terraformVars["existing_sm_instance_crn"] = smCRN
	terraformVars["existing_sm_instance_guid"] = smGuid
	terraformVars["existing_sm_instance_region"] = smRegion

	implicitDestroy := []string{ // Ignore full destroy to speed up tests
		"module.eso_apikey_namespace_secretstore.helm_release.external_secret_store_apikey[0]",
		"module.eso_tp_namespace_secretstore_multisg.helm_release.external_secret_store_tp[0]",
		"module.eso_clusterstore.helm_release.cluster_secret_store_apikey[0]",
		"module.eso_tp_namespace_secretstore_nosecgroup.helm_release.external_secret_store_tp[0]",
		"module.eso_tp_namespace_secretstores[0].helm_release.external_secret_store_tp[0]",
		"module.eso_tp_namespace_secretstores[1].helm_release.external_secret_store_tp[0]",
	}

	options := setupOptionsEnrollEso(t, "esosm", esoEnrollSMExample, implicitDestroy, terraformVars)

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
				"dockerconfigjson-uc":                          namespaces_for_apikey_login[0],
				"dockerconfigjson-arb":                         namespaces_for_apikey_login[2],
				options.Prefix + "-arbitrary-arb-tp-0":         namespaces_for_tp_login[0],
				options.Prefix + "-arbitrary-arb-tp-1":         namespaces_for_tp_login[1],
				options.Prefix + "-arbitrary-arb-tp-multisg-1": "tpns-multisg",
				options.Prefix + "-arbitrary-arb-tp-multisg-2": "tpns-multisg",
				options.Prefix + "-arbitrary-arb-tp-nosg":      "tpns-nosg",
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
