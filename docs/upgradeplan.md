# Updating from version 1.7.0 or earlier

The External Secrets Operator module was redesigned with new features and to allow easier configurations of instances. The last version before the redesign was [1.7.0](https://github.ibm.com/GoldenEye/external-secrets-operator-module/releases/tag/1.7.0).

:exclamation: **Important:** Pay attention to how you update from version 1.7.0 or earlier to the redesigned module. If you update directly, you might cause issues with your deployment.

The following lists outlines some of the changes the prevent a direct update:

- Version 1.7.0 and earlier creates some resources implicitly (for example, `stores` and `externalsecrets`). In later versions, you must define these resources explicitly in the Terraform.

    For example, in version 1.7.0 and earlier, the default value of the `eso_store_setup` input variable is `true`. This value causes the module to create a `ClusterStore` by default (or a `SecretStore` if the value of `eso_store_scope` is `namespace`). In versions after 1.7.0, you instantiate an `eso-clusterstore` or an `eso-secretstore` submodule.

    Likewise, for `externalsecret` resources, version 1.7.0 creates an `externalsecret` resource when it sets up secrets. In later versions, you create `externalsecret` resources through the `eso-external-secret` submodule.
- Some resources have different names in the redesigned version.
- The direct update destroys resources. Secrets that are controlled through the `externalsecrets` resource will also be destroyed, and this will cause disruption.

For more information about the redesign, see GoldenEye issue [4758](https://github.ibm.com/GoldenEye/issues/issues/4758).

## Example of using Terraform move to update with minimal disruption

To update your existing deployments, you can use the Terraform `move` configuration block. For more information about the `move` block, see [Use configuration to move resources](https://developer.hashicorp.com/terraform/tutorials/configuration-language/move-config).

The `docs/upgradeplanexamples` directory in this module contains a set of files to help you with your update, by providing an example of the same terraform template for the `1.7.0` module version and for the redesigned one.

The `.old` files ([variables.tf.old](upgradeplanexamples/variables.tf.old) and [main.tf.old](upgradeplanexamples/main.tf.old)) describe the terraform template to deploy external-secrets-operator module with version 1.7.0.

The `.new` files ([variables.tf.new](upgradeplanexamples/variables.tf.new) and [main.tf.new](upgradeplanexamples/main.tf.new)) describe how to upgrade then to the redesigned version.

The [moved.tf.new](upgradeplanexamples/moved.tf.new) file defines how resources deployed with `1.7.0` template ("old" files) are renamed and moved when the updating with the redesigned version. By adding this file to your template, terraform will update the resources instead of destroying and re-creating them.
