variable "ssh_key" {
  description = "SSH key"
  type        = string
}

variable "hcloud_api_token" {
  description = "Hetzner Cloud Api Token"
  type        = string
}

variable "vps_name" {
  description = "Name of the VPS"
  type        = string
}

variable "vps_image" {
  description = "Image of the VPS"
  type        = string
  default     = "ubuntu-24.04"
}

variable "vps_server_type" {
  description = "Server type of the VPS"
  type        = string
  default     = "ccx13"
}

variable "vps_location" {
  description = "Location of the VPS"
  type        = string
  default     = "hil"
}