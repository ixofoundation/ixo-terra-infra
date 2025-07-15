locals {
  azs = slice(var.availability_zones, 0, var.env_config.az_count)
}