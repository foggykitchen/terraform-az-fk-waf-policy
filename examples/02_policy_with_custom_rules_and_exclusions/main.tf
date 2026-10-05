module "waf_policy" {
  source              = "../.."
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  custom_rules = [{
    name     = "BlockOutsideApprovedClients"
    priority = 10
    action   = "Block"
    match_conditions = [{
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["203.0.113.0/24"]
      match_variables    = [{ variable_name = "RemoteAddr" }]
    }]
  }]
  exclusions = [{
    match_variable          = "RequestArgNames"
    selector                = "searchText"
    selector_match_operator = "Equals"
    excluded_rule_set = {
      rule_groups = [{
        rule_group_name = "SQLI"
        excluded_rules  = ["942100"]
      }]
    }
  }]
}
