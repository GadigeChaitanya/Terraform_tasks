resource "azurerm_route_table" "route_table" {
  name                = "task-route_table"
  location            = azurerm_resource_group.task.location
  resource_group_name = azurerm_resource_group.task.name

  route {
    name           = "route1"
    address_prefix = "10.0.1.0/24"
    next_hop_type  = "VnetLocal"
  }

  route {
    name           = "route2"
    address_prefix = "10.0.2.0/24"
    next_hop_type  = "VnetLocal"
  }

  route {
    name           = "route3"
    address_prefix = "10.0.3.0/24"
    next_hop_type  = "VnetLocal"
  }

  route {
    name           = "route4"
    address_prefix = "10.0.4.0/24"
    next_hop_type  = "VnetLocal"
  }
}

resource "azurerm_subnet_route_table_association" "s1_association" {
  subnet_id      = azurerm_subnet.subnet1.id
  route_table_id = azurerm_route_table.route_table.id
}

resource "azurerm_subnet_route_table_association" "s2_association" {
  subnet_id      = azurerm_subnet.subnet2.id
  route_table_id = azurerm_route_table.route_table.id
}

resource "azurerm_subnet_route_table_association" "s3_association" {
  subnet_id      = azurerm_subnet.subnet3.id
  route_table_id = azurerm_route_table.route_table.id
}

resource "azurerm_subnet_route_table_association" "s4_association" {
  subnet_id      = azurerm_subnet.subnet4.id
  route_table_id = azurerm_route_table.route_table.id
}