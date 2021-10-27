terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 2.46"
    }
  }
}

provider "azurerm" {
  features {

  }
}

# Grupo de recurso
resource "azurerm_resource_group" "rg-atividade" {
  name     = "rg-atividade"
  location = "East US"
}

# Rede virtual
resource "azurerm_virtual_network" "vn-vitual-network" {
  name                = "vn-vitual-network"
  location            = azurerm_resource_group.rg-atividade.location
  resource_group_name = azurerm_resource_group.rg-atividade.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "VirtualRede"
  }
}

# Subnet
resource "azurerm_subnet" "sub-atividade" {
  name                 = "sub-atividade"
  resource_group_name  = azurerm_resource_group.rg-atividade.name
  virtual_network_name = azurerm_virtual_network.vn-vitual-network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Ip publico
resource "azurerm_public_ip" "ip-atividade" {
  name                = "ip-atividade"
  resource_group_name = azurerm_resource_group.rg-atividade.name
  location            = azurerm_resource_group.rg-atividade.location
  allocation_method   = "Static"

  tags = {
    environment = "public_ip"
  }
}

# Grupo de Seguraça
resource "azurerm_network_security_group" "nsg-atividade" {
  name                = "nsg-atividade"
  location            = azurerm_resource_group.rg-atividade.location
  resource_group_name = azurerm_resource_group.rg-atividade.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "mysql"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    }

 tags = {
    environment = "network_security_group"
  }
}

# Interface de Rede
resource "azurerm_network_interface" "ni-atividade" {
  name                = "ni-atividade"
  location            = azurerm_resource_group.rg-atividade.location
  resource_group_name = azurerm_resource_group.rg-atividade.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub-atividade.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-atividade.id
  }
}

# Interface de segurança de rede
resource "azurerm_network_interface_security_group_association" "nisga-atividade" {
  network_interface_id      = azurerm_network_interface.ni-atividade.id
  network_security_group_id = azurerm_network_security_group.nsg-atividade.id
}

# Maquina Virtual
# resource "azurerm_virtual_machine" "vm-atividade" {
#   name                  = "vm-atividade"
#   location              = azurerm_resource_group.rg-atividade.location
#   resource_group_name   = azurerm_resource_group.rg-atividade.name
#   network_interface_ids = [azurerm_network_interface.ni-atividade.id]
#   vm_size               = "Standard_DS1_v2"

#   storage_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }
#   storage_os_disk {
#     name              = "dsk-atividade"
#     caching           = "ReadWrite"
#     #create_option     = "FromImage"
#     managed_disk_type = "Premium_LRS"
#   }
#   os_profile {
#     computer_name  = "vm-atividade"
#     admin_username = "testadmin"
#     admin_password = "Password1234!"
#   }
#   os_profile_linux_config {
#     disable_password_authentication = false
#   }
#   tags = {
#     environment = "staging"
#   }
# }
# ///////////////////////////////
resource "azurerm_linux_virtual_machine" "vm-atividade" {
    name                  = "mysqlteste"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.rg-atividade.name
    network_interface_ids = [azurerm_network_interface.ni-atividade.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDiskMySQL"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "vm-atividade"
    admin_username = "testadmin"
    admin_password = "Password1234!"
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.samsqlteste.primary_blob_endpoint
    }

    depends_on = [ azurerm_resource_group.rg-atividade ]
}

# //////////////////////////////

data "azurerm_public_ip" "ip_atividade_data_db" {
  name                = azurerm_public_ip.ip-atividade.name
  resource_group_name = azurerm_resource_group.rg-atividade.name
}

resource "azurerm_storage_account" "samsqlteste" {
    name                        = "storageaccountmyvm"
    resource_group_name         = azurerm_resource_group.rg-atividade.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Saida
# output "publicip-vm-atividade" {
#   value = azurerm_public_ip.ip-atividade.ip
# }
output "public_ip_address_mysql" {
    value = azurerm_public_ip.ip-atividade.ip_address
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on = [azurerm_linux_virtual_machine.vm-atividade]
  create_duration = "30s"
}

resource "null_resource" "upload_db" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "testadmin"
            password = "Password1234!"
            host = data.azurerm_public_ip.ip_atividade_data_db.ip_address
        }
        source = "config"
        destination = "/home/azureuser"
    }

    depends_on = [ time_sleep.wait_30_seconds_db ]
}

resource "null_resource" "deploy_db" {
    triggers = {
        order = null_resource.upload_db.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = "testadmin"
            password = "Password1234!"
            host = data.azurerm_public_ip.ip_atividade_data_db.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/azureuser/config/user.sql",
            "sudo cp -f /home/azureuser/config/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",
        ]
    }
}