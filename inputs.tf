variable "name" {
  nullable    = false
  description = "Name of the Azure Web Application Firewall Policy."
  type        = string
  validation {
    condition     = trimspace(var.name) != ""
    error_message = "name must not be empty."
  }
}

variable "resource_group_name" {
  nullable    = false
  description = "Existing Resource Group containing the Web Application Firewall Policy."
  type        = string
}

variable "location" {
  nullable    = false
  description = "Azure region of the Web Application Firewall Policy."
  type        = string
}

variable "policy_settings" {
  nullable    = false
  description = "Web Application Firewall Policy inspection, size limits, enforcement and mode settings."
  type = object({
    enabled                          = optional(bool, true)
    mode                             = optional(string, "Prevention")
    request_body_check               = optional(bool, true)
    file_upload_limit_in_mb          = optional(number, 100)
    max_request_body_size_in_kb      = optional(number, 128)
    request_body_inspect_limit_in_kb = optional(number, 128)
    request_body_enforcement         = optional(bool, true)
    file_upload_enforcement          = optional(bool, true)
  })
  default = {}
  validation {
    condition = (
      contains(["Detection", "Prevention"], var.policy_settings.mode) &&
      var.policy_settings.file_upload_limit_in_mb >= 1 && var.policy_settings.file_upload_limit_in_mb <= 4000 && floor(var.policy_settings.file_upload_limit_in_mb) == var.policy_settings.file_upload_limit_in_mb &&
      var.policy_settings.max_request_body_size_in_kb >= 8 && var.policy_settings.max_request_body_size_in_kb <= 2000 && floor(var.policy_settings.max_request_body_size_in_kb) == var.policy_settings.max_request_body_size_in_kb &&
      var.policy_settings.request_body_inspect_limit_in_kb >= 8 && var.policy_settings.request_body_inspect_limit_in_kb <= 2000 && floor(var.policy_settings.request_body_inspect_limit_in_kb) == var.policy_settings.request_body_inspect_limit_in_kb
    )
    error_message = "mode must be Detection or Prevention; upload must be an integer 1..4000 MB; body and inspection limits must be integers 8..2000 KB."
  }
}

variable "managed_rule_sets" {
  nullable    = false
  description = "Managed rule sets and per-group rule overrides; default Microsoft Default Rule Set 2.2."
  type = list(object({
    type    = optional(string, "Microsoft_DefaultRuleSet")
    version = optional(string, "2.2")
    rule_group_overrides = optional(list(object({
      rule_group_name = string
      rules = optional(list(object({
        id      = string
        enabled = optional(bool, false)
        action  = optional(string)
      })), [])
    })), [])
  }))
  default = [{}]
  validation {
    condition = (
      length(var.managed_rule_sets) > 0 &&
      length(distinct([for s in var.managed_rule_sets : s.type])) == length(var.managed_rule_sets) &&
      alltrue([for s in var.managed_rule_sets : contains(lookup({
        OWASP                       = ["2.2.9", "3.0", "3.1", "3.2"]
        Microsoft_DefaultRuleSet    = ["2.1", "2.2"]
        Microsoft_BotManagerRuleSet = ["0.1", "1.0", "1.1"]
      }, s.type, []), s.version)]) &&
      length([for s in var.managed_rule_sets : s if contains(["OWASP", "Microsoft_DefaultRuleSet"], s.type)]) == 1 &&
      alltrue([for s in var.managed_rule_sets : length(distinct([for g in s.rule_group_overrides : g.rule_group_name])) == length(s.rule_group_overrides)]) &&
      alltrue(flatten([for s in var.managed_rule_sets : [for g in s.rule_group_overrides :
        length(distinct([for r in g.rules : r.id])) == length(g.rules) && alltrue([for r in g.rules : trimspace(r.id) != "" && (r.action == null ? true : contains(["Allow", "Block", "Log", "AnomalyScoring", "JSChallenge"], r.action)) && (r.action != "JSChallenge" || s.type == "Microsoft_BotManagerRuleSet")])
      ]]))
    )
    error_message = "Provide exactly one OWASP or Microsoft Default Rule Set, optionally one Bot Manager set, with supported versions, unique types/groups/rule IDs and valid actions. JSChallenge overrides require Bot Manager."
  }
}

variable "custom_rules" {
  nullable    = false
  description = "Custom match or rate-limit rules; unique names and priorities, evaluated before managed rules."
  type = list(object({
    name                 = string
    priority             = number
    rule_type            = optional(string, "MatchRule")
    action               = string
    enabled              = optional(bool, true)
    rate_limit_duration  = optional(string)
    rate_limit_threshold = optional(number)
    group_rate_limit_by  = optional(string)
    match_conditions = list(object({
      operator           = string
      negation_condition = optional(bool, false)
      match_values       = optional(list(string), [])
      transforms         = optional(set(string), [])
      match_variables = list(object({
        variable_name = string
        selector      = optional(string)
      }))
    }))
  }))
  default = []
  validation {
    condition = (
      length(var.custom_rules) <= 100 &&
      length(distinct([for r in var.custom_rules : r.priority])) == length(var.custom_rules) &&
      length(distinct([for r in var.custom_rules : r.name])) == length(var.custom_rules) &&
      alltrue([for r in var.custom_rules : trimspace(r.name) != "" && r.priority >= 1 && r.priority <= 100 && floor(r.priority) == r.priority &&
        contains(["MatchRule", "RateLimitRule"], r.rule_type) && contains(["Allow", "Block", "Log", "JSChallenge"], r.action) && length(r.match_conditions) > 0 &&
        (r.rule_type == "RateLimitRule" ? (
          r.action != "Allow" && contains(["OneMin", "FiveMins"], coalesce(r.rate_limit_duration, "unset")) &&
          (r.rate_limit_threshold == null ? false : r.rate_limit_threshold >= 1 && floor(r.rate_limit_threshold) == r.rate_limit_threshold) &&
          contains(["ClientAddr", "ClientAddrXFFHeader", "GeoLocation", "GeoLocationXFFHeader", "None"], coalesce(r.group_rate_limit_by, "unset"))
        ) : r.rate_limit_duration == null && r.rate_limit_threshold == null && r.group_rate_limit_by == null)
      ]) &&
      alltrue(flatten([for r in var.custom_rules : [for c in r.match_conditions :
        contains(["Any", "IPMatch", "GeoMatch", "Equal", "Contains", "LessThan", "GreaterThan", "LessThanOrEqual", "GreaterThanOrEqual", "BeginsWith", "EndsWith", "Regex"], c.operator) &&
        (c.operator == "Any" || length(c.match_values) > 0) && length(c.match_variables) > 0 &&
        alltrue([for v in c.match_variables : contains(["RemoteAddr", "RequestMethod", "QueryString", "PostArgs", "RequestUri", "RequestHeaders", "RequestBody", "RequestCookies"], v.variable_name)]) &&
        alltrue([for t in c.transforms : contains(["HtmlEntityDecode", "Lowercase", "RemoveNulls", "Trim", "Uppercase", "UrlDecode", "UrlEncode"], t)])
      ]]))
    )
    error_message = "Custom rules require unique names and integer priorities 1..100, valid match conditions/actions, and values unless Any. RateLimitRule requires duration, positive integer threshold and grouping, prohibits Allow; MatchRule prohibits rate-limit fields."
  }
}

variable "exclusions" {
  nullable    = false
  description = "Match-variable exclusions; omit excluded_rule_set for global scope or select one set/group/rule."
  type = list(object({
    match_variable          = string
    selector                = string
    selector_match_operator = string
    excluded_rule_set = optional(object({
      type    = optional(string, "Microsoft_DefaultRuleSet")
      version = optional(string, "2.2")
      rule_groups = optional(list(object({
        rule_group_name = string
        excluded_rules  = optional(list(string), [])
      })), [])
    }))
  }))
  default = []
  validation {
    condition = (
      alltrue([for e in var.exclusions :
        contains(["RequestArgKeys", "RequestArgNames", "RequestArgValues", "RequestCookieKeys", "RequestCookieNames", "RequestCookieValues", "RequestHeaderKeys", "RequestHeaderNames", "RequestHeaderValues"], e.match_variable) &&
        contains(["Contains", "EndsWith", "Equals", "EqualsAny", "StartsWith"], e.selector_match_operator) && trimspace(e.selector) != "" &&
        (e.selector_match_operator != "EqualsAny" || e.selector == "*") &&
        (e.excluded_rule_set == null ? true : contains(lookup({
          OWASP                       = ["3.2"]
          Microsoft_DefaultRuleSet    = ["2.1", "2.2"]
          Microsoft_BotManagerRuleSet = ["1.0", "1.1"]
        }, e.excluded_rule_set.type, []), e.excluded_rule_set.version))
      ])
    )
    error_message = "Exclusions require a supported match variable/operator and nonempty selector; EqualsAny requires *. Scoped exclusions require a supported type/version."
  }
}

variable "tags" {
  nullable    = false
  description = "Tags assigned to the Web Application Firewall Policy."
  type        = map(string)
  default     = {}
}
