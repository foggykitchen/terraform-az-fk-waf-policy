# terraform-az-fk-waf-policy

This repository contains a reusable **Terraform / OpenTofu module** and progressive examples for deploying a standalone **Azure Web Application Firewall Policy** — starting from a minimal Prevention policy and evolving toward custom rules, exclusions, and Detection-mode tuning.

It is part of the **[FoggyKitchen.com training ecosystem](https://foggykitchen.com/courses)** and is designed as a **clean, composable application security layer** that can be centrally governed, versioned, and audited independently of any gateway lifecycle.

Support expectations are documented in [SUPPORT.md](SUPPORT.md).

---

## Used By

This module is designed to be used as a focused building block wherever centrally governed Web Application Firewall Policies are composed with independently managed Application Gateways.

## 🎯 Purpose

Create one Web Application Firewall Policy, including its inspection settings, managed rule sets, custom rules, and exclusions. Reference its ID from one or more [terraform-az-fk-application-gateway](https://github.com/foggykitchen/terraform-az-fk-application-gateway) instances through that module's `firewall_policy_id` input.

Azure Firewall is a separate network security and egress service owned by [terraform-az-fk-firewall](https://github.com/foggykitchen/terraform-az-fk-firewall). This module owns only an HTTP application security policy.

---

## ✨ What the module does

The module creates:

- One `azurerm_web_application_firewall_policy`
- Policy mode, inspection limits, upload limits, and size enforcement settings
- Managed rule sets with per-group rule state/action overrides
- Custom match and rate-limit rules
- Global or rule-scoped match-variable exclusions

The module intentionally does not create:

- Application Gateway resources or frontend, backend, listener, probe, or routing configuration
- Resource Groups, VNets, subnets, or any networking resource
- Diagnostic settings or Log Analytics Workspaces
- Azure Firewall or network-layer firewall rules

Each of those concerns belongs in its own dedicated module or workflow layer. A policy does not inspect traffic until a consuming gateway attaches it.

---

## Provider Notes

Live discovery on **2026-10-05** verified the [AzureRM 4.81.0 resource documentation](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/web_application_firewall_policy.html.markdown), [resource schema](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/internal/services/network/web_application_firewall_policy_resource.go), and [rule-set validators](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/internal/services/network/validate/web_application_firewall_policy.go). This release uses `Microsoft.Network` API `2025-01-01`.

The static FoggyKitchen provider constraint remains `>= 3.100.0, < 5.0.0`, matching the Application Gateway sibling. The [live registry](https://registry.terraform.io/providers/hashicorp/azurerm) lists 5.8.0 overall and 4.81.0 as the latest within this range. **Use AzureRM 4.81.0 for this module's verified schema.** Older locked releases, including 3.100.0, lack the body/file enforcement arguments; the shared version range is not a claim that this complete contract works with every older release. Run `tofu init -upgrade` when upgrading an older lock. Lock files are intentionally ignored in this module repository.

### Managed rules

The default is `Microsoft_DefaultRuleSet` version `2.2`: [Microsoft recommends DRS 2.2](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules), based on CRS 3.3.4 with additional Microsoft protections. It is accepted by AzureRM 4.81.0. The module supports exactly one baseline set, optionally with one Bot Manager set:

| Type | Supported versions |
|------|--------------------|
| `Microsoft_DefaultRuleSet` | `2.1`, `2.2` |
| `OWASP` | `2.2.9`, `3.0`, `3.1`, `3.2` |
| `Microsoft_BotManagerRuleSet` | `0.1`, `1.0`, `1.1` |

Provider validators check types and versions separately; the module also validates their pairing and unique types. Both Detection and Prevention accept the modern default; no provider mode/version mutual exclusion was found. Legacy rule sets have different service limits and capabilities. Prefer the default modern engine.

`rule_group_overrides[].rules[]` maps to provider `rule_group_override { rule { id, enabled, action } }`. Set `enabled = false` to disable a specific rule. **An override entry defaults to disabled**, matching the provider; set `enabled = true` explicitly when changing only the action. Do not use the removed `disabled_rules` syntax. Omitted rules retain Azure's defaults. Rule IDs and group names must belong to the selected set: DRS 2.2 uses `PROTOCOL-ENFORCEMENT` and `SQLI`, whereas OWASP 3.2 uses `REQUEST-920-PROTOCOL-ENFORCEMENT` and `REQUEST-942-APPLICATION-ATTACK-SQLI`. Keep overrides and exclusions under review when changing versions.

Override actions are `Allow`, `AnomalyScoring`, `Block`, `Log`, or `JSChallenge` in the provider. Azure support depends on the rule type: DRS/CRS normally use `AnomalyScoring`, `Block`, or `Log`; Bot Manager supports `Allow`, `Block`, `Log`, and `JSChallenge`. JavaScript challenge overrides require Bot Manager. Log scrubbing and challenge-cookie expiry are available in the provider but outside this module's focused contract.

### Custom rules and mode

[Custom rule priorities](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/custom-waf-rules-overview) must be unique integers from 1 to 100; lower numbers evaluate first regardless of list position. Names must also be unique. The module enforces these Azure requirements even though the provider's priority field has no range/uniqueness validator. Custom rules run before managed rules. In Prevention mode, `Allow` and `Block` terminate evaluation; `Log` continues. A broad Allow rule can therefore bypass managed inspection. The example uses a negated-IP Block rule so approved clients continue through managed rules.

Detection mode logs matches and permits requests, including custom Block rules; it is a tuning stage, not blocking protection. In Prevention mode, default managed anomaly scoring aggregates matches before blocking. Enable gateway diagnostics before tuning and review evidence before moving to Prevention.

`MatchRule` and `RateLimitRule` support custom actions `Allow`, `Block`, `Log`, and `JSChallenge`; rate-limit rules prohibit `Allow`. The provider's `Invalid` rule type is intentionally rejected. Every rule needs at least one match condition and match variable; values are required unless the operator is `Any`. Conditions within a rule combine with AND, while values within a condition combine with OR. Operators are `Any`, `IPMatch`, `GeoMatch`, `Equal`, `Contains`, `LessThan`, `GreaterThan`, `LessThanOrEqual`, `GreaterThanOrEqual`, `BeginsWith`, `EndsWith`, and `Regex`. Match variables are `RemoteAddr`, `RequestMethod`, `QueryString`, `PostArgs`, `RequestUri`, `RequestHeaders`, `RequestBody`, and `RequestCookies`. Transforms are `HtmlEntityDecode`, `Lowercase`, `RemoveNulls`, `Trim`, `Uppercase`, `UrlDecode`, and `UrlEncode`; the provider models them as a set, so order is not a contract.

[Rate limiting](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/rate-limiting-overview) requires the modern engine (OWASP 3.2 or DRS). Supply `OneMin` or `FiveMins`, a positive integer threshold, and one grouping: `ClientAddr`, `ClientAddrXFFHeader`, `GeoLocation`, `GeoLocationXFFHeader`, or `None`. Match rules must omit rate-only fields. The provider supports one grouping rather than combinations. Counters are independent across attachments and gateway instances; a shared policy does not provide one global request quota. Air-gapped clouds do not support rate-limit rules.

### Inspection and exclusions

`policy_settings` is a singleton object. All fields are optional: enabled/inspection/enforcement default to true, mode to Prevention, upload to 100 MB, and body size/inspection to 128 KB. [Size enforcement and inspection depth are separate](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-request-size-limits). Provider upload limits are 1..4000 MB and body size 8..2000 KB. The provider accepts a nonnegative inspection limit without a maximum; this module deliberately restricts it to 8..2000 KB for the modern engine. Extended limits and independent enforcement switches require modern rule sets. In Detection mode, oversized bodies are not rejected by policy size enforcement and can be only partially inspected.

[Exclusions](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-configuration) apply under `managed_rules`, not to custom rules. Match variables are `RequestArgKeys`, `RequestArgNames`, `RequestArgValues`, `RequestCookieKeys`, `RequestCookieNames`, `RequestCookieValues`, `RequestHeaderKeys`, `RequestHeaderNames`, and `RequestHeaderValues`. Selectors use `Equals`, `EqualsAny`, `Contains`, `StartsWith`, or `EndsWith`; `EqualsAny` requires `*` and excludes all matching attributes. Prefer exact, rule-scoped exclusions. Regex selectors are unsupported.

An exclusion can optionally target **one** `excluded_rule_set` object: the 4.81.0 source imposes `MaxItems: 1`, despite documentation saying one or more. Scoped versions are DRS 2.1/2.2, OWASP 3.2, or Bot Manager 1.0/1.1. The type/version must match a configured set. Omit rule groups to exclude across that set; omit rule IDs to exclude across the group; omit the whole object for global managed-rule scope.

### Diagnostics and sharing

[Web Application Firewall traffic logs](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/web-application-firewall-logs) are generated and enabled on each consuming Application Gateway. Diagnostic settings target the gateway, not this policy. Consequently, this module accepts no misleading workspace-ID input. Configure the gateway sibling's `diagnostic_settings` with an externally provided Log Analytics Workspace ID.

A single policy can be [associated with multiple gateways](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/create-waf-policy-ag). Use compatible `WAF_v2` gateways in the policy's region. All consumers share the same rule changes; govern those changes centrally and detach consumers before deleting a policy. The gateway sibling's `firewall_policy_id` and `inline_waf_configuration` are mutually exclusive.

---

## 📂 Repository Structure

```text
terraform-az-fk-waf-policy/
├── examples/
│   ├── 01_basic_prevention_policy/
│   ├── 02_policy_with_custom_rules_and_exclusions/
│   ├── 03_detection_mode_with_rule_overrides/
│   └── README.md
├── main.tf
├── inputs.tf
├── outputs.tf
├── versions.tf
├── SUPPORT.md
├── LICENSE
└── README.md
```

Each example contains `main.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, and `README.md`. The root follows the sibling convention of `inputs.tf`; example inputs live in `variables.tf`.

---

## 🚀 Example Usage

```hcl
module "waf_policy" {
  source = "git::https://github.com/foggykitchen/terraform-az-fk-waf-policy.git?ref=v0.1.0"

  name                = "fk-shared-web-policy"
  resource_group_name = "fk-security-rg"
  location            = "westeurope"
  tags                = { project = "foggykitchen", env = "dev" }
}
```

In each separately composed gateway module, set:

```hcl
sku_name           = "WAF_v2"
firewall_policy_id = module.waf_policy.waf_policy_id
```

Keep the gateway's frontend, backend, listener, probe, and routing configuration in the gateway module.

---

## 📥 Module Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | `string` | yes | — | Name of the Azure Web Application Firewall Policy. |
| `resource_group_name` | `string` | yes | — | Existing Resource Group containing the Web Application Firewall Policy. |
| `location` | `string` | yes | — | Azure region of the Web Application Firewall Policy. |
| `policy_settings` | `object` | no | `{}` | Web Application Firewall Policy inspection, size limits, enforcement and mode settings. |
| `managed_rule_sets` | `list(object)` | no | `[{}]` | Managed rule sets and per-group rule overrides; default Microsoft Default Rule Set 2.2. |
| `custom_rules` | `list(object)` | no | `[]` | Custom match or rate-limit rules; unique names and priorities, evaluated before managed rules. |
| `exclusions` | `list(object)` | no | `[]` | Match-variable exclusions; omit excluded_rule_set for global scope or select one set/group/rule. |
| `tags` | `map(string)` | no | `{}` | Tags assigned to the Web Application Firewall Policy. |

### Object schemas

The complete typed inputs, including nested defaults, are:

```hcl
policy_settings = object({
    enabled                          = optional(bool, true)
    mode                             = optional(string, "Prevention")
    request_body_check               = optional(bool, true)
    file_upload_limit_in_mb          = optional(number, 100)
    max_request_body_size_in_kb      = optional(number, 128)
    request_body_inspect_limit_in_kb = optional(number, 128)
    request_body_enforcement         = optional(bool, true)
    file_upload_enforcement          = optional(bool, true)
  })
```

```hcl
managed_rule_sets = list(object({
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
```

```hcl
custom_rules = list(object({
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
```

```hcl
exclusions = list(object({
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
```

---

## 📤 Module Outputs

| Output | Description |
|--------|-------------|
| `waf_policy_id` | The ID of the Azure Web Application Firewall Policy. |
| `waf_policy_name` | The name of the Azure Web Application Firewall Policy. |
| `waf_policy_location` | The Azure region of the Web Application Firewall Policy. |

---

## 🧭 Examples

- `01_basic_prevention_policy`: minimal Prevention policy using DRS 2.2
- `02_policy_with_custom_rules_and_exclusions`: IP boundary Block rule plus one rule-scoped argument exclusion
- `03_detection_mode_with_rule_overrides`: log-only policy with an explicit managed rule disable for tuning

See [examples/README.md](examples/README.md). Examples use an existing Resource Group and create only the policy. All three have passed static validation; all three examples were additionally deployed and their configurations verified against Azure on 2026-10-05. Traffic enforcement has not been tested because no gateway was attached.

---

## 🧠 Design Philosophy

- Explicit inputs and policy-ID composition
- Central governance independent of gateway lifecycle
- Small modules over monoliths
- Security policy separated from networking, application delivery, and monitoring destinations
- Optimized for learning, reuse, and auditability

---

## 🧩 Related Modules & Training

- [terraform-az-fk-application-gateway](https://github.com/foggykitchen/terraform-az-fk-application-gateway)
- [terraform-az-fk-key-vault](https://github.com/foggykitchen/terraform-az-fk-key-vault)
- [terraform-az-fk-log-analytics](https://github.com/foggykitchen/terraform-az-fk-log-analytics)

See [examples](examples/README.md) for progressive Web Application Firewall Policy scenarios.

---

## 🪪 License

Licensed under the **Universal Permissive License (UPL), Version 1.0**.
See [LICENSE](LICENSE) for details.

---

© 2026 [FoggyKitchen.com](https://foggykitchen.com) - Cloud. Code. Clarity.
