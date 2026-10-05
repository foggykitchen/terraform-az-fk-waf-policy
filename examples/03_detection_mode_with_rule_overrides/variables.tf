variable "resource_group_name" {
  description = "Existing Resource Group; this example creates only a Web Application Firewall Policy."
  type        = string
}
variable "location" {
  description = "Azure region; must match the consuming Application Gateway."
  type        = string
  default     = "westeurope"
}
variable "waf_policy_name" {
  description = "Name of the Web Application Firewall Policy."
  type        = string
  default     = "fk-policy-03"
}
variable "tags" {
  description = "Web Application Firewall Policy tags."
  type        = map(string)
  default     = { project = "foggykitchen", env = "dev" }
}
