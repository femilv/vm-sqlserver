provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "ia-rasaq-vnet"
  location = "EastUs"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "ia-rasaq-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "ia-rasaq-subnet"
  address_prefix       = "10.0.1.0/24"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_public_ip" "public-ip" {
  name                = "ia-rasaq-pubilc-IP"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "network-interface" {
  name                = "ia-rasaq-network-int"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "ip-configuration-Eastus"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.public-ip.id}"
  }
}

resource "azurerm_storage_account" "storage-account" {
  name                     = "ia-storage-account-eastus"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "ia-vm-east"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.network-interface.id}"]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2019-WS2019"
    sku       = "Enterprise"
    version   = "latest"
  }

  storage_os_disk {
    name              = "os-disk-eastus"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm-eastus"
    admin_username = "myadminuser"
    admin_password = "MyP@ssw0rd1234!"
  }

  os_profile_windows_config {
    enable_automatic_updates = true
    provision_vm_agent       = true
  }

  provisioner "remote-exec" {
    inline = [
      "Invoke-WebRequest -Uri 'https://aka.ms/vs/16/release/vc_redist.x64.exe' -OutFile 'c:/temp/vc_redist.x64.exe'",
"Start-Process -Wait -FilePath 'c:/temp/vc_redist.x64.exe' -ArgumentList '/quiet /norestart'"
]
}
}

resource "azurerm_network_security_group" "network-security-group" {
name = "ia-nsg-eastus"
location = "${azurerm_resource_group.rg.location}"
resource_group_name = "${azurerm_resource_group.rg.name}"

security_rule {
name = "allow-rdp"
priority = 100
direction = "Inbound"
access = "Allow"
protocol = "Tcp"
source_port_range = ""
destination_port_range = "3389"
source_address_prefix = ""
destination_address_prefix = "*"
}
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-association" {
network_interface_id = "${azurerm_network_interface.network-interface.id}"
network_security_group_id = "${azurerm_network_security_group.network-security-group.id}"
}
