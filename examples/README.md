# Azure Web Application Firewall Policy with Terraform/OpenTofu – Training Examples

This directory contains all progressive examples used with the **terraform-az-fk-waf-policy** module.
The examples are designed as **incremental building blocks**, starting from a minimal Prevention policy and gradually evolving toward custom rules, exclusions, and Detection-mode tuning.

These examples are part of the **[FoggyKitchen.com training ecosystem](https://foggykitchen.com/courses)** and are used across Azure and multicloud courses focused on security and application delivery.

---

## 🧭 Example Overview

| Example | Title | Key Topics |
|:-------:|:------|:-----------|
| 01 | **Basic Prevention Policy** | Standalone Web Application Firewall Policy, Microsoft Default Rule Set 2.2, Prevention mode |
| 02 | **Policy with Custom Rules and Exclusions** | Negated IP-match Block rule, rule-scoped argument exclusion, managed inspection |
| 03 | **Detection Mode with Rule Overrides** | Log-only tuning, managed rule group override, explicit rule disable |

Each example builds on the **concepts** introduced in the previous one, but can be applied independently for learning and experimentation.

---

## ⚙️ How to Use

Each example directory contains:

- Terraform/OpenTofu configuration (`.tf`)
- A focused `README.md` explaining the goal of the example
- A minimal architecture centered on one Web Application Firewall Policy capability
- A nonsecret `terraform.tfvars.example` for an existing Resource Group

To validate the first example:

```bash
cd examples/01_basic_prevention_policy
cp terraform.tfvars.example terraform.tfvars
tofu fmt -check
tofu init
tofu validate
```

Use AzureRM 4.81.0 for the verified schema. All examples have passed static validation. All three examples were additionally deployed and their policy settings verified against Azure on 2026-10-05; no gateway traffic test was performed. Set your subscription and credentials in your environment before deploying.

You can apply examples independently, but the **recommended learning approach is sequential**:
01 → 02 → 03

This sequence introduces the policy contract, scoped customization, and a realistic tuning workflow. For an existing production application, tune in Detection mode before enabling Prevention.

---

## 🧩 Design Principles

- One example = one architectural goal
- No unused or placeholder gateway configuration
- Only the Web Application Firewall Policy is created
- Clear separation of concerns between policy, gateway, networking, and monitoring
- Existing dependency names are explicit inputs
- Policy IDs are outputs for composition with the focused gateway module

These examples intentionally avoid:

- Full landing zones
- Opinionated enterprise frameworks
- Hidden dependencies between examples
- Production secrets or subscription-specific values in source control

---

## 🧩 Related Resources

- [FoggyKitchen Azure Web Application Firewall Policy Module (terraform-az-fk-waf-policy)](../)
- [FoggyKitchen Azure Application Gateway Module (terraform-az-fk-application-gateway)](https://github.com/foggykitchen/terraform-az-fk-application-gateway)
- [FoggyKitchen Azure Log Analytics Module (terraform-az-fk-log-analytics)](https://github.com/foggykitchen/terraform-az-fk-log-analytics)
- [Provider Notes and typed policy contract](../README.md#provider-notes)

---

## 🪪 License

Licensed under the **Universal Permissive License (UPL), Version 1.0**.
See [LICENSE](../LICENSE) for details.

---

© 2026 [FoggyKitchen.com](https://foggykitchen.com) - Cloud. Code. Clarity.
