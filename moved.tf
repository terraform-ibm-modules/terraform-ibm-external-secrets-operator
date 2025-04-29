# this move section is needed to avoid es-operator destroy during module upgrade
moved {
  from = kubernetes_namespace.eso_namespace[0]
  to   = module.eso_namespace[0].kubernetes_namespace.create_namespace["es-operator"]
}
