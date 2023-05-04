terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gadige" {
  name     = "gadige-rg"
  location = var.location
}

resource "random_string" "fqdn" { #The resource random_string generates a random permutation of alphanumeric characters and optionally special characters.This resource does use a cryptographic random number generator.
 length  = 6
 special = false
 upper   = false
 number  = true
}

resource "azurerm_virtual_network" "gadige" {
  name                = "gadige-vn"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name
}

resource "azurerm_subnet" "gadige" {
  name                 = "gadige-subnet"
  resource_group_name  = azurerm_resource_group.gadige.name
  virtual_network_name = azurerm_virtual_network.gadige.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "gadige" {
  name                = "gadigee-pubIP"
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result           #domain_name_label must be specified to get the fqdn
  #Fully qualified domain name of the A DNS record associated with the public IP
}

resource "azurerm_lb" "gadige" {
  name                = "gadige-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.gadige.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpool" {
  loadbalancer_id = azurerm_lb.gadige.id
  name            = "Backendaddresspool"
}

resource "azurerm_lb_probe" "gadige" {
  resource_group_name = azurerm_resource_group.gadige.name
  loadbalancer_id     = azurerm_lb.gadige.id
  name                = "ssh-running-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.gadige.name
  loadbalancer_id                = azurerm_lb.gadige.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.gadige.id
}

resource "azurerm_virtual_machine_scale_set" "gadige" {
  name                = "vmscaleset"
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2 #Specifies the number of virtual machines in the scale set.
  }

   storage_profile_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "16.04-LTS"
     version   = "latest"
   }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite" #Specifies the caching requirements. Possible values include:ReadOnly, ReadWrite
    create_option     = "FromImage" # Specifies how the virtual machine should be created. The only possible option is FromImage
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0 #Specifies the Logical Unit Number of the disk in each virtual machine in the scale set.
    caching       = "ReadWrite"
    create_option = "Empty" #Specifies how the data disk should be created. The only possible options are FromImage and Empty.
    disk_size_gb  = 10
  }

  os_profile { #administrator acc name
    computer_name_prefix = "vmlab"
    admin_username       = var.admin_user
    admin_password       = var.admin_password
    custom_data          = file("web.conf")
  }

   os_profile_linux_config {
     disable_password_authentication = false
   }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.gadige.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpool.id]
      primary                                = true
    }
  }
}

#A Jumpbox can provide remote access to the LAN and even to the devices on a LAN. It then acts as a mini gateway on the LAN and allows you to access the LAN and then ‘jump’ via SSH or other services to other connected devices on that LAN.
resource "azurerm_public_ip" "jb" {
  name                = "jb-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-ssh"    #random_string.fqdn.result
}

resource "azurerm_network_interface" "jb" {
  name                = "jb-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.gadige.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.gadige.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.jb.id
  }
}

resource "azurerm_virtual_machine" "jb" {
  name                  = "jumpbox"
  location              = var.location
  resource_group_name   = azurerm_resource_group.gadige.name
  network_interface_ids = [azurerm_network_interface.jb.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "jumpbox-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "jumpbox"
    admin_username = var.admin_user
    admin_password = var.admin_password
  }
 os_profile_linux_config {
     disable_password_authentication = false
   }
  
}