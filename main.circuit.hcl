# Facts give each host's architecture, which picks the release tarball.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(keys(local.node_arch), self.arch)
      error_message = "Host ${each.key} is ${self.arch}. This circuit installs the linux-x64 and linux-arm64 builds."
    }
  }
}

locals {
  node_arch = { x86_64 = "x64", aarch64 = "arm64" }
  arch      = { for name in keys(var.hosts) : name => lookup(local.node_arch, data.conn3x_host.facts[name].arch, data.conn3x_host.facts[name].arch) }
  release   = { for name, a in local.arch : name => "node-v${var.node_version}-linux-${a}" }
  home      = { for name, r in local.release : name => "/opt/nodejs/${r}" }
}

circuit "nodejs" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tool" {
    for_each = ["curl", "tar", "gzip"]
    package {
      name = item.value
    }
  }

  # The official builds link these two, and minimal images often lack them.
  step "libatomic" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libatomic1" : "libatomic"
    }
  }

  step "libstdcxx" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libstdc++6" : "libstdc++"
    }
  }

  step "dir" {
    directory {
      path = "/opt/nodejs"
    }
  }

  # The download step keeps the tarball only if it matches the checksum,
  # which comes from the release's SHASUMS256.txt.
  step "download" {
    download {
      url    = "https://nodejs.org/dist/v${var.node_version}/${local.release[each.key]}.tar.gz"
      sha256 = var.checksums[local.arch[each.key]]
      dest   = "/opt/nodejs/${local.release[each.key]}.tar.gz"
    }
  }

  step "unpack" {
    archive {
      src     = "/opt/nodejs/${local.release[each.key]}.tar.gz"
      dest    = "/opt/nodejs"
      creates = "${local.home[each.key]}/bin/node"
    }
  }

  step "link" {
    for_each = ["node", "npm", "npx"]
    link {
      path   = "/usr/local/bin/${item.value}"
      target = "${local.home[each.key]}/bin/${item.value}"
    }
  }

  step "npmrc_dir" {
    directory {
      path = "${local.home[each.key]}/etc"
    }
  }

  # Left to itself, npm would install global packages inside this release's
  # directory, off the PATH, and leave them behind on the next node_version.
  step "npmrc" {
    file {
      path    = "${local.home[each.key]}/etc/npmrc"
      content = "# Written by Conn3x. Changes here are overwritten on the next apply.\nprefix=/usr/local\n"
      mode    = "0644"
    }
  }

  # sudo's secure_path leaves out /usr/local/bin on the Red Hat family, and
  # npm's shebang finds node through PATH. A new Node.js runs the install
  # again, since a package's native addons are built for one release.
  step "global_package" {
    for_each = var.global_packages
    command {
      command  = "PATH=/usr/local/bin:$PATH npm install --global --no-audit --no-fund '${item.key}@${item.value}'"
      unless   = "[ \"$(/usr/local/bin/node -p \"require('/usr/local/lib/node_modules/${item.key}/package.json').version\" 2>/dev/null)\" = '${item.value}' ]"
      triggers = { node = var.node_version }
    }
  }
}
