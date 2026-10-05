module "waf_policy" {
  source              = "../.."
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings = { mode = "Detection" }
  managed_rule_sets = [{
    rule_group_overrides = [{
      rule_group_name = "PROTOCOL-ENFORCEMENT"
      rules           = [{ id = "920310", enabled = false }]
    }]
  }]
}
