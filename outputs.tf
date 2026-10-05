output "waf_policy_id" {
  description = "The ID of the Azure Web Application Firewall Policy."
  value       = azurerm_web_application_firewall_policy.this.id
}

output "waf_policy_name" {
  description = "The name of the Azure Web Application Firewall Policy."
  value       = azurerm_web_application_firewall_policy.this.name
}

output "waf_policy_location" {
  description = "The Azure region of the Web Application Firewall Policy."
  value       = azurerm_web_application_firewall_policy.this.location
}
