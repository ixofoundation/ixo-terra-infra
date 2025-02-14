variable "environment" {}
variable "aws_region" {}
variable "chain_names" {
  type = list(string)
}
variable "metadata_chains" {
  type = list(string)
}