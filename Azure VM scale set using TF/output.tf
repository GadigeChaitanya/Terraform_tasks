output "gadige_public_ip_fqdn" {
  value = azurerm_public_ip.gadige.fqdn
}

output "jumpbox_public_ip_fqdn" {
  value = azurerm_public_ip.jb.fqdn
}

output "jb_public_ip" {
  value = azurerm_public_ip.jb.ip_address
}