terraform {
  required_version = ">= 1.4.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.45.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_api_token
}

module "server" {
  source               = "./.tf-modules/hetzner-vps-bare"
  vps                  = {
    name                 = var.vps_name
    image                = var.vps_image
    server_type          = var.vps_server_type
    location             = var.vps_location
    ssh_keys             = [var.ssh_key]
  }
}