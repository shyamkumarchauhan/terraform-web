variable "count" {
    default = 1
  }
variable "region" {
  description = "AWS region for hosting our your network"
  default = "us-east-2"
}
variable "public_key_path" {
  description = "Enter the path to the SSH Public Key to add to AWS."
  default = "/home/ubuntu/terraform.pem"
}
variable "key_name" {
  description = "Key name for SSHing into EC2"
  default = "terraform"
}
variable "amis" {
  description = "Base AMI to launch the instances"
  default = {
  us-east-2 = "ami-7ea88d1b"
  }
}
variable "username" {
  type = "list"
  default = ["developer-1","developer-2","developer-3"]
}
