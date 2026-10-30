variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "node_version" {
  type        = string
  default     = "26.13.0"
  description = "Node.js release to install, such as \"26.13.0\". Change checksums with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.node_version))
    error_message = "node_version must look like \"26.13.0\", without a leading v."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the linux-x64 and linux-arm64 .tar.gz tarballs, from the release's SHASUMS256.txt. Change these with node_version."
  default = {
    x64   = "5848553868b402d3fabb5b09270649977780a390f832155721025a08b5104455"
    arm64 = "439e9c438acdf6a6ffe47418da709153d66c4bed812e30a473faacb107dd2791"
  }

  validation {
    condition     = alltrue([for c in values(var.checksums) : can(regex("^[0-9a-f]{64}$", c))])
    error_message = "Each of checksums must be a SHA-256 in lowercase hex."
  }
}

variable "global_packages" {
  type        = map(string)
  default     = {}
  description = "npm packages to install globally, by name, each at an exact version, such as { semver = \"7.8.5\" }."

  validation {
    condition     = alltrue([for name in keys(var.global_packages) : can(regex("^(@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]*$", name))])
    error_message = "Each key of global_packages must be an npm package name, such as \"semver\" or \"@scope/name\"."
  }

  validation {
    condition     = alltrue([for v in values(var.global_packages) : can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$", v))])
    error_message = "Each version in global_packages must be exact, such as \"7.8.5\", not a range or a tag."
  }
}
