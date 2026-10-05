output "waf_policy_id" {
  description = "Web Application Firewall Policy ID for a consuming gateway."
  value       = module.waf_policy.waf_policy_id
}
output "waf_policy_name" {
  description = "Web Application Firewall Policy name."
  value       = module.waf_policy.waf_policy_name
}
