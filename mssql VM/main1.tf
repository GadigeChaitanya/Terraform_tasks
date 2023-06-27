terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "chaiturg" {
  name     = "chaiturg-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "chaiturg" {
  name                = "chaitu-VN"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.chaiturg.location
  resource_group_name = azurerm_resource_group.chaiturg.name
}

resource "azurerm_subnet" "chaiturg" {
  name                 = "chaitu-subnet"
  resource_group_name  = azurerm_resource_group.chaiturg.name
  virtual_network_name = azurerm_virtual_network.chaiturg.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "chaiturg" {
  name                = "chaitu-PIP"
  location            = azurerm_resource_group.chaiturg.location
  resource_group_name = azurerm_resource_group.chaiturg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_machine" "chaiturg" {
  name                  = "chaitu-VM"
  location              = azurerm_resource_group.chaiturg.location
  resource_group_name   = azurerm_resource_group.chaiturg.name
  network_interface_ids = [azurerm_network_interface.chaiturg.id]
  vm_size               = "Standard_DS14_v2"

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2017-WS2016"
    sku       = "SQLDEV"
    version   = "latest"
  }

  storage_os_disk {
    name              = "OSDisk"
    caching           = "ReadOnly"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "winhost01"
    admin_username = "exampleadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
    timezone                  = "Pacific Standard Time"
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }
}

resource "azurerm_network_security_group" "chaiturg" {
  name                = "chaitu-nsg"
  location            = azurerm_resource_group.chaiturg.location
  resource_group_name = azurerm_resource_group.chaiturg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "chaiturg" {
  subnet_id                 = azurerm_subnet.chaiturg.id
  network_security_group_id = azurerm_network_security_group.chaiturg.id
}

resource "azurerm_network_interface_security_group_association" "chaiturg" {
  network_interface_id      = azurerm_network_interface.chaiturg.id
  network_security_group_id = azurerm_network_security_group.chaiturg.id
}

resource "azurerm_mssql_virtual_machine" "chaiturg" {
  virtual_machine_id               = data.azurerm_virtual_machine.chaiturg.id
  sql_license_type                 = "PAYG"
  r_services_enabled               = true
  sql_connectivity_port            = 1433
  sql_connectivity_type            = "PRIVATE"
  sql_connectivity_update_password = "Password1234!"
  sql_connectivity_update_username = "sqllogin"
}

resource "azurerm_network_security_rule" "MSSQLRule" {
  name                        = "MSSQLRule"
  resource_group_name         = azurerm_resource_group.chaiturg.name
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = 1433
  source_address_prefix       = "167.220.255.0/25"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.chaiturg.name
}

resource "azurerm_lb" "chaiturg" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.chaiturg.location
  resource_group_name = azurerm_resource_group.chaiturg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.chaiturg.id
  }
}

resource "azurerm_lb_rule" "chaiturg" {
  loadbalancer_id                = azurerm_lb.chaiturg.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "chaiturg" {
  loadbalancer_id = azurerm_lb.chaiturg.id
  name            = "sql-probe"
  port            = 1433
}

resource "azurerm_lb_backend_address_pool" "chaiturg1" {
  loadbalancer_id = azurerm_lb.chaiturg.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_interface" "chaiturg" { #public ip dependecies required.
  name                = "chaiturg-NIC"
  location            = azurerm_resource_group.chaiturg.location
  resource_group_name = azurerm_resource_group.chaiturg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.chaiturg.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.chaiturg.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "chaiturg" {
  network_interface_id    = azurerm_network_interface.chaiturg.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.chaiturg1.id
}

