module "waf_policy" {
  source              = "../.."
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
