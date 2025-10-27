terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.25.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  custom_data = <<SETUP
#!/bin/bash
sudo usermod -aG docker,libvirt netlab 
sudo -u netlab vagrant plugin install vagrant-libvirt --plugin-version 0.12.2
sudo -u netlab git clone https://github.com/bgplab/bgplab.git /home/netlab/bgplab
sudo -u netlab vagrant box add /opt/images/iosv-15.7-3.M3-box.json
sudo -u netlab vagrant box add /opt/images/iosvl2-15.2-box.json
sudo -u netlab vagrant box add /opt/images/eos-4.31.2F-box.json
sudo -u netlab vagrant box add /opt/images/csr-16.6.1-box.json
sudo -u netlab mkdir /home/netlab/initial
sudo -u netlab cp /etc/openvpn/simple.yml /home/netlab/initial/topology.yml
sudo -u netlab touch /home/netlab/.ssh/config
sudo -u netlab cat <<SSH  > /home/netlab/.ssh/config
  KexAlgorithms +diffie-hellman-group14-sha1
  HostKeyAlgorithms +ssh-rsa
SSH
SETUP
}

resource "azurerm_resource_group" "vlab" {
  name     = var.rg-name
  location = "UK West"
}


resource "azurerm_network_security_group" "netlab" {
  name                = "NSG.netlab"
  location            = azurerm_resource_group.vlab.location
  resource_group_name = azurerm_resource_group.vlab.name

  security_rule {
    name                       = "allow-openvpn"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Development"
  }
}


resource "azurerm_virtual_network" "vlab" {
  name                = "VLAB-vnet"
  location            = azurerm_resource_group.vlab.location
  resource_group_name = azurerm_resource_group.vlab.name
  address_space       = ["10.2.0.0/16"]

  tags = {
    environment = "Development"
  }
}

resource "azurerm_subnet" "lan" {
  name                 = "VLAB-LAN-subnet"
  resource_group_name  = azurerm_resource_group.vlab.name
  virtual_network_name = azurerm_virtual_network.vlab.name
  address_prefixes     = ["10.2.0.0/24"]
  
}  

resource "azurerm_route_table" "lan" {
  name                          = "RT.vLAB"
  location                      = azurerm_resource_group.vlab.location
  resource_group_name           = azurerm_resource_group.vlab.name
  disable_bgp_route_propagation = false

  route {
    name                   = "UDR.VMnetlab"
    address_prefix         = "192.168.122.0/24"
    next_hop_type          = "VirtualAppliance"
	next_hop_in_ip_address = "10.2.0.4"
  }

  route {
    name                   = "UDR.Local"
    address_prefix         = "172.16.253.0/24"
    next_hop_type          = "VirtualAppliance"
	next_hop_in_ip_address = "10.2.0.4"
  }
  
  tags = {
    environment = "Development"
  }
}


resource "azurerm_subnet_route_table_association" "vlab" {
  subnet_id      = azurerm_subnet.lan.id
  route_table_id = azurerm_route_table.lan.id
}


resource "azurerm_public_ip" "netlab" {
  name                = "VM.netlab-public-ipv4"
  resource_group_name = azurerm_resource_group.vlab.name
  location            = azurerm_resource_group.vlab.location
  domain_name_label   = var.vm-host
  allocation_method   = "Static"

  tags = {
    environment = "Development"
  }
}


resource "azurerm_network_interface" "netlab" {
  name                = "VM.netlab-nic"
  location            = azurerm_resource_group.vlab.location
  resource_group_name = azurerm_resource_group.vlab.name

  ip_configuration {
    name                          = "netlab-ipv4"
    subnet_id                     = azurerm_subnet.lan.id
    private_ip_address_allocation = "Static"
	private_ip_address            = "10.2.0.4"
	public_ip_address_id          = azurerm_public_ip.netlab.id
  }
  
  enable_ip_forwarding = true
  
  tags = {
    environment = "Development"
  }
}

resource "azurerm_network_interface_security_group_association" "netlab" {
  network_interface_id      = azurerm_network_interface.netlab.id
  network_security_group_id = azurerm_network_security_group.netlab.id
}


resource "azurerm_linux_virtual_machine" "netlab" {
  name                = "VM-netlab"
  location            = azurerm_resource_group.vlab.location
  resource_group_name = azurerm_resource_group.vlab.name
  size                = "Standard_E16s_v5"
  admin_username      = "netlab"
  custom_data         = base64encode(local.custom_data)
  network_interface_ids = [
    azurerm_network_interface.netlab.id
  ]

  admin_ssh_key {
    username   = "netlab"
    public_key = file("~/.ssh/netlab.pub")
  }
  
  eviction_policy = "Deallocate"
  max_bid_price = 0.25
  priority = "Spot"
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
    
  source_image_id = var.base-image
   
  tags = {
    environment = "Development"
  }
}