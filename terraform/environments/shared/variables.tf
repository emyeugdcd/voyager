variable "location" {
  type        = string
  description = "The Azure region to deploy resources to."
  default     = "northeurope"
}

variable "project" {
  type        = string
  description = "Consistent project name prefix."
  default     = "voyager"
}

variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID."
  default     = "16ae35b8-3311-486c-b92e-edfd46b1e826"
}

variable "monthly_budget_eur" {
  type        = number
  description = "The monthly budget limit in EUR."
  default     = 50
}

variable "alert_email" {
  type        = string
  description = "The email address for budget alerts."
  default     = "lducanh1991@gmail.com"
}
