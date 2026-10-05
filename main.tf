resource "azurerm_web_application_firewall_policy" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                          = var.policy_settings.enabled
    mode                             = var.policy_settings.mode
    request_body_check               = var.policy_settings.request_body_check
    file_upload_limit_in_mb          = var.policy_settings.file_upload_limit_in_mb
    max_request_body_size_in_kb      = var.policy_settings.max_request_body_size_in_kb
    request_body_inspect_limit_in_kb = var.policy_settings.request_body_inspect_limit_in_kb
    request_body_enforcement         = var.policy_settings.request_body_enforcement
    file_upload_enforcement          = var.policy_settings.file_upload_enforcement
  }

  managed_rules {
    dynamic "managed_rule_set" {
      for_each = var.managed_rule_sets
      content {
        type    = managed_rule_set.value.type
        version = managed_rule_set.value.version
        dynamic "rule_group_override" {
          for_each = managed_rule_set.value.rule_group_overrides
          content {
            rule_group_name = rule_group_override.value.rule_group_name
            dynamic "rule" {
              for_each = rule_group_override.value.rules
              content {
                id      = rule.value.id
                enabled = rule.value.enabled
                action  = rule.value.action
              }
            }
          }
        }
      }
    }
    dynamic "exclusion" {
      for_each = var.exclusions
      content {
        match_variable          = exclusion.value.match_variable
        selector                = exclusion.value.selector
        selector_match_operator = exclusion.value.selector_match_operator
        dynamic "excluded_rule_set" {
          for_each = exclusion.value.excluded_rule_set == null ? [] : [exclusion.value.excluded_rule_set]
          content {
            type    = excluded_rule_set.value.type
            version = excluded_rule_set.value.version
            dynamic "rule_group" {
              for_each = excluded_rule_set.value.rule_groups
              content {
                rule_group_name = rule_group.value.rule_group_name
                excluded_rules  = rule_group.value.excluded_rules
              }
            }
          }
        }
      }
    }
  }

  dynamic "custom_rules" {
    for_each = var.custom_rules
    content {
      name                 = custom_rules.value.name
      priority             = custom_rules.value.priority
      rule_type            = custom_rules.value.rule_type
      action               = custom_rules.value.action
      enabled              = custom_rules.value.enabled
      rate_limit_duration  = custom_rules.value.rate_limit_duration
      rate_limit_threshold = custom_rules.value.rate_limit_threshold
      group_rate_limit_by  = custom_rules.value.group_rate_limit_by
      dynamic "match_conditions" {
        for_each = custom_rules.value.match_conditions
        content {
          operator           = match_conditions.value.operator
          negation_condition = match_conditions.value.negation_condition
          match_values       = match_conditions.value.match_values
          transforms         = match_conditions.value.transforms
          dynamic "match_variables" {
            for_each = match_conditions.value.match_variables
            content {
              variable_name = match_variables.value.variable_name
              selector      = match_variables.value.selector
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = alltrue([for e in var.exclusions : e.excluded_rule_set == null ? true : anytrue([for s in var.managed_rule_sets : s.type == e.excluded_rule_set.type && s.version == e.excluded_rule_set.version])])
      error_message = "Scoped exclusions must reference a configured managed rule set type and version."
    }
    precondition {
      condition     = !anytrue([for r in var.custom_rules : r.rule_type == "RateLimitRule"]) || anytrue([for s in var.managed_rule_sets : s.type == "Microsoft_DefaultRuleSet" || (s.type == "OWASP" && s.version == "3.2")])
      error_message = "Rate-limit rules require the modern engine: OWASP 3.2 or Microsoft Default Rule Set."
    }
  }
}
