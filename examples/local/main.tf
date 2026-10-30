variable "port" {
  type    = number
  default = 2309
}

module "nodejs" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  global_packages = { semver = "7.8.5" }
}

output "node_home" {
  value = module.nodejs.node_home
}
