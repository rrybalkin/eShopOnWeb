
variable "subscription_id" {
  description = "Azure subscription ID to use for resources"
  default = "00c11214-6ab3-4ae6-9433-cbf4f13b24ad"
}

variable "tenant_id" {
  description = "Azure tenant ID to use for resources"
  default = "b41b72d0-4e9f-4c26-8a69-f949f367c91d"
}

variable "my_username" {
  description = "My personal username to be used as Admin for some services"
  default = "Roman_Rybalkin@epam.com"
}

variable "my_external_email" {
  description = "My external email to be used for notifications"
  default = "roman.rybalkin24@gmail.com"
}

variable "my_object_id" {
  description = "My personal user object ID to be used as Admin for some services"
  default = "b8f868a8-17c1-4a92-a33e-c07742ac9a01"
}

variable "resource_group_name" {
  description = "Unique resource group name"
  default = "cloudxfinalassignment"
}

variable "resource_name_prefix" {
  description = "A kind of unique prefix used in resources naming"
  default = "cloudxfinaltaskdemo"
}

variable "eshop_webapp_name" {
  description = "eShop Web application naming for resources"
  default = "cloudxeshopwebapp"
}

variable "eshop_publicapi_name" {
  description = "eShop Public API application naming for resources"
  default = "cloudxeshoppublicapi"
}

variable "eshop_webapp_sku" {
  description = "SKU name for eShop Web application instances. Default is S1 to enable deployment slots and autoscaling."
  default = "S1"
}

variable "eshop_webapp_replica_sku" {
  description = "SKU name for eShop Web application instances. Default is F1 to reduce costs."
  default = "F1"
}

variable "eshop_publicapi_sku" {
  description = "SKU name for eShop Public API application instances"
  default = "F1"
}

variable "primary_region" {
  description = "Primary target region to deploy resources"
  default = "eastus"
}

variable "secondary_region" {
  description = "Secondary target region to deploy replica resources"
  default = "westeurope"
}

variable "sql_db_region" {
  description = "Azure region to deploy SQL, not all regions supported"
  default = "northeurope"
}

variable "sql_db_admin_login" {
  description = "Administrator username for SQL database"
  default = "romanadmin"
}

variable "sql_db_admin_password" {
  description = "Administrator password for SQL database"
}

variable "ip_restriction_default_action" {
  default = "Allow"
}

variable "scm_ip_restriction_default_action" {
  default = "Allow"
}

variable "enable_web_autoscale" {
  description = "A flag to enable/disable Web app autoscaling based on CPU"
  default = true
}

variable "web_autoscale_cpu_threshold" {
  description = "CPU threshold in percentage when to trigger autoscale up and down"
  default = 70
}

variable "enable_webapp_replica" {
  description = "A flag to enable/disable Web App replica deployment"
  default = true
}

variable "enable_traffic_manager" {
  description = "A flag to enable/disable traffic manager resources deployment"
  default = true
}

variable "enable_staging_slot" {
  description = "A flag to enable/disable staging slot deployment for Web app"
  default = true
}
