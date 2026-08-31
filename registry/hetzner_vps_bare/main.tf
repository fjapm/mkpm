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
  source               = "github.com/fjapm/terraform-modules.git//hetzner-vps-bare"
  
  vps                  = {
    name                 = var.vps_name
    image                = var.vps_image
    server_type          = var.vps_server_type
    location             = var.vps_location
    ssh_authorized_keys  = var.vps_ssh_authorized_keys
  }

  # cloudinit_config_packages = [
  #   "pkg-a",
  #   "pkg-b"
  # ]

  # cloudinit_config_write_files = [
  #   {
  #     path        = "path/to/file/on/vps"
  #     permissions = "0644"
  #     content     = file("${path.module}/local-file.yml")
  #   },
  #   {
  #     path        = "path/to/another/file/on/vps"
  #     permissions = "0644"
  #     content     = templatefile("${path.module}/another-local-file-as-template.tftpl", {
  #       name                 = "name"
  #       https_port           = "443"
  #       local_port           = "11000"
  #     })
  #   },
  # ]

  # cloudinit_config_runcmd = [
  #   [ "bash", "-lc", "<command>" ]
  # ]


}