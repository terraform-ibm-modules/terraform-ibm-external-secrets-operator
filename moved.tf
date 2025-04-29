# this move section is needed to avoid es-operator destroy during module upgrade
moved {
  from = module.external_secrets_operator.kubernetes_namespace.eso_namespace[0]
  to   = module.external_secrets_operator.module.eso_namespace[0].kubernetes_namespace.create_namespace["es-operator"]
}
