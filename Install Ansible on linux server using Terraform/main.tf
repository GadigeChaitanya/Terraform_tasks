terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "Chaitu-rg" {
  name     = "Chaitulx-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.Chaitu-rg.location
  resource_group_name = azurerm_resource_group.Chaitu-rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "my-subnet"
  resource_group_name  = azurerm_resource_group.Chaitu-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "my-PIP"
  location            = azurerm_resource_group.Chaitu-rg.location
  resource_group_name = azurerm_resource_group.Chaitu-rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "my-nsg"
  location            = azurerm_resource_group.Chaitu-rg.location
  resource_group_name = azurerm_resource_group.Chaitu-rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "myLinux-nic"
  location            = azurerm_resource_group.Chaitu-rg.location
  resource_group_name = azurerm_resource_group.Chaitu-rg.name

  ip_configuration {
    name                          = "myLinux-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nisg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# resource "random_integer" "digits" {
#   min = 1
#   max = 10
# }
resource "random_id" "random_id" {
  keepers = {
    resource_group = azurerm_resource_group.Chaitu-rg.name
  }
  byte_length = 8
}

resource "azurerm_storage_account" "boodia" { #n your Terraform code to generate a random 5-digit integer.
  name                     = "diag${random_id.random_id.hex}" #"bdia${random_integer.digits.result}"
  resource_group_name      = azurerm_resource_group.Chaitu-rg.name
  location                 = azurerm_resource_group.Chaitu-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "Pemfile" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "linuxvm.pem"
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                  = "Chaitu-linuxVM"
  location              = azurerm_resource_group.Chaitu-rg.location
  resource_group_name   = azurerm_resource_group.Chaitu-rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_B1ls"

  os_disk {
    name                 = "mylinuxOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name = "ChaituLinuxvm"
  admin_username = "Chaitanya"
  admin_password = "Linux@123"

  admin_ssh_key {
    username   = "Chaitanya"
    public_key = file("~/.ssh/id_rsa.pub") #tls_private_key.ssh_key.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.boodia.primary_blob_endpoint
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y software-properties-common",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt install -y ansible"
    ]

    connection {
      type        = "ssh"
      user        = "Chaitanya"
      private_key = file("~/.ssh/id_rsa")
      host        = azurerm_linux_virtual_machine.linux_vm.public_ip_address
    }
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo apt update",
  #     "sudo apt install -y software-properties-common",
  #     "sudo apt-add-repository --yes --update ppa:ansible/ansible",
  #     "sudo apt install -y ansible"
  #     # "sudo apt-get update",
  #     # "sudo apt-get install software-properties-common -y",
  #     # "sudo apt-add-repository ppa:ansible/ansible -y",
  #     # "sudo apt-get update",
  #     # "sudo apt-get install ansible -y"
  #   ]
    
  #   connection {
  #     host        = azurerm_linux_virtual_machine.linux_vm.public_ip_address
  #     type        = "ssh"
  #     user        = "Chaitanya"
  #     private_key = file("~/.ssh/linux_rsa")
  #   }
  }


# resource "null_resource" "set_file_permissions" {
#   provisioner "local-exec" {
#     command = "chmod 600 /path/to/private_key_file"
#   }

#   depends_on = [
#     azurerm_linux_virtual_machine.linux_vm
#   ]
#   }






