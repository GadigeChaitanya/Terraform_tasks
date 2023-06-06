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
  location = "Eastus" #var.location
}

resource "azurerm_virtual_network" "gadige" {
  name                = "gadige-vn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gadige.location
  resource_group_name = azurerm_resource_group.gadige.name
}

resource "azurerm_subnet" "gadige" {
  count                = 3
  name                 = "gadige-subnet-${count.index}"
  resource_group_name  = azurerm_resource_group.gadige.name
  virtual_network_name = azurerm_virtual_network.gadige.name
  address_prefixes     = ["10.0.${count.index}.0/24"]

  #   delegation {
  #     name = "delegation"

  #     service_delegation {
  #       name    = "Microsoft.ContainerInstance/containerGroups"
  #       actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
  #     }
  #   }
}

resource "azurerm_network_interface" "nic" {
  count               = 3
  name                = "gadige-nic-${count.index}"
  location            = azurerm_resource_group.gadige.location
  resource_group_name = azurerm_resource_group.gadige.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.gadige[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "gadige" {
  count               = 3
  name                = "public-ip-${count.index}"
  location            = azurerm_resource_group.gadige.location
  resource_group_name = azurerm_resource_group.gadige.name
  allocation_method   = "Static"
}

resource "azurerm_availability_set" "availability_set" {
  name                = "gadige-availability-set"
  resource_group_name = azurerm_resource_group.gadige.name
  location            = azurerm_resource_group.gadige.location
}

resource "azurerm_virtual_machine" "vm" {
  count                 = 3
  name                  = "vm-${count.index}"
  location              = azurerm_resource_group.gadige.location
  resource_group_name   = azurerm_resource_group.gadige.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  vm_size               = "Standard_B1ls"
  availability_set_id   = azurerm_availability_set.availability_set.id


  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "os-disk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "my-vm-${count.index}"
    admin_username = "azureuser"
    admin_password = "Passwd@123"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_network_security_group" "gadige" {
  name                = "my-nsg"
  location            = azurerm_resource_group.gadige.location
  resource_group_name = azurerm_resource_group.gadige.name

  security_rule {
    name                       = "Test1"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "gadige" {
  count                     = 3
  subnet_id                 = azurerm_subnet.gadige[count.index].id
  network_security_group_id = azurerm_network_security_group.gadige.id
}

# resource "azurerm_network_profile" "net_profile" {
#   name                = "gadige-netprofile"
#   location            = azurerm_resource_group.gadige.location
#   resource_group_name = azurerm_resource_group.gadige.name

#   container_network_interface {
#     name = "gadige-cnic"

#     ip_configuration {
#       name      = "exampleipconfig"
#       subnet_id = azurerm_subnet.gadige[0].id

#     }
#   }
# }

resource "azurerm_lb" "gadige_lb" {
  name                = "gadige-lb"
  resource_group_name = azurerm_resource_group.gadige.name
  location            = azurerm_resource_group.gadige.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name      = "FrontendIP"
    subnet_id = azurerm_subnet.gadige[0].id # Use the first subnet for the frontend IP
  }
}

resource "azurerm_lb_backend_address_pool" "gadige_backend_pool" {
  loadbalancer_id = azurerm_lb.gadige_lb.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "gadige_probe" {
  resource_group_name = azurerm_resource_group.gadige.name
  loadbalancer_id     = azurerm_lb.gadige_lb.id
  name                = "ssh-running-probe"
  port                = 22
}

resource "azurerm_lb_rule" "gadige_rule" {
  resource_group_name            = azurerm_resource_group.gadige.name
  loadbalancer_id                = azurerm_lb.gadige_lb.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = azurerm_lb.gadige_lb.frontend_ip_configuration[0].name
  #backend_address_pool_ids        = azurerm_lb_backend_address_pool.gadige_backend_pool.id
  probe_id = azurerm_lb_probe.gadige_probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "gadige" {
  count                   = 3
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = azurerm_network_interface.nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.gadige_backend_pool.id
}

locals {
  first_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKYr1rJybKgCXTTUQOnXrfVRQj4k5umJsdbsT7UXYj63ysSeIz3QXGMKz7flh9G4lfrqpoGcaj+fF2oaC5lO9nnz6d1RiUAQYWe0/5gQ4f2vOY4O0L21VO9zFG/0mQeBA+IfgbuKcW/fAdqfCWukpjq0R+32B4/uWNRp0XJfitCp1BEGFKxhkMq8/SDojcib+ufMdEgtSET5ZZRF19OEyyY1CaRf7EIbAXqMLNVoFwGE1uSeCfExGw5EWSYM6k4hT6sRHe0nQA5d0kbiORMAqhhhc9t6h+oBWDvX/XecA4dY9OqIMa/BKYTqwDcxyjLuTxxwTOl/AFDL96RSIsMz3Mi87J6jVhHyetkb5td1gHgoGi4t/5OCgOmiHBiQ9nSxoL4GSGylAgzEMMklqcnObMBOVmobX7y4DSIlG/Rtorru6ABWGeCOMtPmfUgKJN76Qafe5rgxhFkTk4GwRUyvrPQc5KE/2FGcVnYOG/Mz+UkWP2fz5IQ4/A9AWxYFU9xRs= chaitanyavm@chaitanya-vm"
}

resource "azurerm_linux_virtual_machine_scale_set" "gadige" {
  name                = "vmscaleset"
  location            = azurerm_resource_group.gadige.location
  resource_group_name = azurerm_resource_group.gadige.name
  sku                 = "Standard_B1ls"
  instances           = 3
  admin_username      = "azureuser"
  admin_password      = "Passwd@123"

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.first_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "tfnetproflie"
      primary                                = true
      subnet_id                              = azurerm_subnet.gadige[0].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.gadige_backend_pool.id]
    }
  }
}

resource "azurerm_monitor_autoscale_setting" "gadige" {
  name                = "autoscale"
  resource_group_name = azurerm_resource_group.gadige.name
  location            = azurerm_resource_group.gadige.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.gadige.id

  profile {
    name = "scale-up"

    capacity {
      default = 3
      minimum = 2
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.gadige.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.gadige.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

resource "azurerm_storage_account" "to_monitor" {
  name                     = "gadigestorageaccount"
  resource_group_name      = azurerm_resource_group.gadige.name
  location                 = azurerm_resource_group.gadige.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_monitor_action_group" "main" {
  name                = "gadige-actiongroup"
  resource_group_name = azurerm_resource_group.gadige.name
  short_name          = "gadigeact"

  webhook_receiver {
    name        = "callmyapi"
    service_uri = "http://example.com/alert"
  }
}

resource "azurerm_monitor_metric_alert" "gadige" {
  name                = "scale-up-metric-alert"
  resource_group_name = azurerm_resource_group.gadige.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.gadige.id]

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 50

    # dimensions {
    #   name     = "ApiName"
    #   operator = "Include"
    #   values   = ["*"]
    # }
  }
}