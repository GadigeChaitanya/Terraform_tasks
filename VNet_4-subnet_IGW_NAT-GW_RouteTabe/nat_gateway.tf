resource "azurerm_subnet" "task" {
  name                 = "nat-subnet"
  resource_group_name  = azurerm_resource_group.task.name
  virtual_network_name = azurerm_virtual_network.task.name
  address_prefixes     = ["10.0.5.0/24"]
}

resource "azurerm_public_ip" "nat_public_ip" {
  name                = "task-nat_public_ip"
  location            = azurerm_resource_group.task.location
  resource_group_name = azurerm_resource_group.task.name
  allocation_method   = "Static"
}

resource "azurerm_nat_gateway" "nat_gateway" {
  name                    = "task-nat_gateway"
  location                = azurerm_resource_group.task.location
  resource_group_name     = azurerm_resource_group.task.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_subnet_nat_gateway_association" "s1_nat_association" {
  subnet_id      = azurerm_subnet.subnet1.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "s2_nat_association" {
  subnet_id      = azurerm_subnet.subnet2.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "s3_nat_association" {
  subnet_id      = azurerm_subnet.subnet3.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "s4_nat_association" {
  subnet_id      = azurerm_subnet.subnet4.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}