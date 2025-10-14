variable "base-image" {
  description = "netlab Base Build + OS Image"
  type        = string
}

variable "rg-name" {
  description = "Resource Group where netlab VM will be Built. Suggested format RG.<yourinitials>vLAB"
  type        = string
}

variable "vm-host" {
  description = "Resource Group where netlab VM will be Built. Suggested format <yourinitials>netlabvlab"
  type        = string
}

output "netlab-fqdn" {
    value = azurerm_public_ip.netlab.fqdn
  description = "Fully Qualified Doamon Name for NetLab VM"
}