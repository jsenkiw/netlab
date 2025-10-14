packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

source "azure-arm" "ubuntu" {
  use_azure_cli_auth                = true
  managed_image_resource_group_name = "RG.LAB-Images"
  managed_image_name                = "NetLab-VM-Image-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "ubuntu-pro-gen1"

  azure_tags = {
    Created-by  = "Packer"
    OS_Version  = "Ubuntu 24.04"
    Release     = "Latest"
    Application = "NetLab"
  }

  location = "UK West"
  vm_size  = "Standard_E4s_v5"
}

build {
  name = "ubuntu"
  sources = [
    "source.azure-arm.ubuntu",
  ]

  provisioner "shell" {
    inline = [
      "echo Installing Updates",
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  provisioner "shell" {
    inline = [
	  "echo Install OpenVPN + NetLab",
      "sudo apt-get install -y nmap python3-pip openvpn easy-rsa",
      "sudo pip3 install --ignore-installed --break-system-packages networklab",
      "sudo pip3 install --upgrade --break-system-packages  pyopenssl cryptography",
      "netlab install -y ubuntu ansible libvirt containerlab",
      "mkdir -p /tmp/images"
    ]
  }

  provisioner "shell" {
    only   = ["source.azure-arm.ubuntu*"]
    inline = ["sudo apt-get install -y azure-cli"]
  }

  provisioner "file" {
    source      = "./images"
    destination = "/tmp"
  }

  provisioner "file" {
    sources     = ["server.conf", "secret.key", "simple.yml"]
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/images",
      "sudo cp -r /tmp/images/ /opt",
      "sudo cp /tmp/secret.key /tmp/server.conf /tmp/simple.yml /etc/openvpn",
      "sudo sysctl -w net.ipv4.ip_forward=1"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo Copy Local Files to OpenVPN Directory",
      "cp client.conf.ovpn secret.key ~/OpenVPN/config"
    ]
  }
}