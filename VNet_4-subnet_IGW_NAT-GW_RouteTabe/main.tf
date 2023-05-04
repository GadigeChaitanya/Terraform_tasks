provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "task" {
  name     = "task-name"
  location = "East US"
}

resource "azurerm_virtual_network" "task" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.task.location
  resource_group_name = azurerm_resource_group.task.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.task.name
  virtual_network_name = azurerm_virtual_network.task.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "subnet2"
  resource_group_name  = azurerm_resource_group.task.name
  virtual_network_name = azurerm_virtual_network.task.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "subnet3" {
  name                 = "subnet3"
  resource_group_name  = azurerm_resource_group.task.name
  virtual_network_name = azurerm_virtual_network.task.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "subnet4" {
  name                 = "subnet4"
  resource_group_name  = azurerm_resource_group.task.name
  virtual_network_name = azurerm_virtual_network.task.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "task-pip"
  location            = azurerm_resource_group.task.location
  resource_group_name = azurerm_resource_group.task.name
  allocation_method   = "Dynamic" 
}

resource "azurerm_network_interface" "nic" {
  name                = "task-nic"
  location            = azurerm_resource_group.task.location
  resource_group_name = azurerm_resource_group.task.name

  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}