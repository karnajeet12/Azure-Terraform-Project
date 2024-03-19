terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.95.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
  }
}

resource "azurerm_resource_group" "AzureTerraformProjectRG" {
  name     = "AzureTerraformProject-ResourceGroup"
  location = "East US"
  tags = {
    environment = "Azure & Terraform"
  }
}

resource "azurerm_virtual_network" "AzureTerraformProjectVNet" {
  name                = "AzureTerraformProject-VirtualNetwork"
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name
  location            = azurerm_resource_group.AzureTerraformProjectRG.location
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = "Azure & Terraform"
  }

}

resource "azurerm_subnet" "AzureTerraformProjectSubnet" {
  name                 = "AzureTerraformProject-Subnet"
  resource_group_name  = azurerm_resource_group.AzureTerraformProjectRG.name
  virtual_network_name = azurerm_virtual_network.AzureTerraformProjectVNet.name
  address_prefixes     = ["10.1.0.0/24"]

}

resource "azurerm_network_security_group" "AzureTerraformProjectSG" {
  name                = "AzureTerraformProject-SecurityGroup"
  location            = azurerm_resource_group.AzureTerraformProjectRG.location
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name

  tags = {
    environment = "Azure & Terraform"
  }

}

resource "azurerm_network_security_rule" "AzureTerraformPorjectRule" {
  name                        = "AzureTerraformProject-SecurityRule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "99.224.57.131/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.AzureTerraformProjectRG.name
  network_security_group_name = azurerm_network_security_group.AzureTerraformProjectSG.name
}

resource "azurerm_subnet_network_security_group_association" "AzureTerraformProjectSGAssociation" {
  subnet_id                 = azurerm_subnet.AzureTerraformProjectSubnet.id
  network_security_group_id = azurerm_network_security_group.AzureTerraformProjectSG.id

}

resource "azurerm_public_ip" "AzureTerraformProjectPubIP" {
  name                = "AzureTerraformProject-PublicIP"
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name
  location            = azurerm_resource_group.AzureTerraformProjectRG.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Azure & Terraform"
  }

}

resource "azurerm_network_interface" "AzureTerraformProjectNetworkInterfaceCard" {
  name                = "AzureTerraformProject-NetworkInterfaceCard"
  location            = azurerm_resource_group.AzureTerraformProjectRG.location
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.AzureTerraformProjectSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.AzureTerraformProjectPubIP.id
  }

  tags = {
    environment = "Azure & Terraform"
  }

}

resource "azurerm_linux_virtual_machine" "AzureTerraformProjectVirtualMachine" {
  name                = "AzureTerraformProject-VirtualMachine"
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name
  location            = azurerm_resource_group.AzureTerraformProjectRG.location
  size                = "Standard_F2"
  admin_username      = "Karnajeet"
  network_interface_ids = [
    azurerm_network_interface.AzureTerraformProjectNetworkInterfaceCard.id,
  ]

  custom_data = filebase64("customdata.tpl")


  admin_ssh_key {
    username   = "Karnajeet"
    public_key = file("~/.ssh/AzureTerraformProjectKeyPair.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "Karnajeet",
      identityfile = "~/.ssh/AzureTerraformProjectKeyPair"
    })

    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]

  }
  tags = {
    environment = "Azure & Terraform"
  }
}

data "azurerm_public_ip" "AzureTerraformProjectPublicIP" {
  resource_group_name = azurerm_resource_group.AzureTerraformProjectRG.name
  name = "AzureTerraformProject-PublicIP"
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.AzureTerraformProjectVirtualMachine.name} : ${data.azurerm_public_ip.AzureTerraformProjectPublicIP.ip_address}"
}