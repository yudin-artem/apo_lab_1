locals {
  ubuntu_base_volume_name = "${var.vm_name}--ubuntu-base.qcow2"
  root_volume_name        = "${var.vm_name}-root.qcow2"
  cloudinit_volume_name   = "${var.vm_name}-cloudinit.iso"
}

resource "libvirt_volume" "ubuntu_base" {
  name = local.ubuntu_base_volume_name
  pool = var.storage_pool

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }
}

resource "libvirt_volume" "root" {
  name = local.root_volume_name
  pool = var.storage_pool

  capacity      = var.vm_disk_size_gib * 1024 * 1024 * 1024
  capacity_unit = "bytes"

  backing_store = {
    path = libvirt_volume.ubuntu_base.path

    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }

    permissions = {
      owner = "64055"
      group = "993"
      mode  = "0600"
    }
  }
}

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.vm_name}-seed.iso"

  user_data = templatefile(
    "${path.module}/cloud-init.yaml.tftpl",
    {
      vm_name = var.vm_name
      vm_user = var.vm_user
      ssh_public_key = trimspace(
        file(pathexpand(var.ssh_public_key_path))
      )
    }
  )

  meta_data = yamlencode({
    "instance-id"    = var.vm_name
    "local-hostname" = var.vm_name
  })
}

resource "libvirt_volume" "cloudinit" {
  name = local.cloudinit_volume_name
  pool = var.storage_pool

  target = {
    permissions = {
      owner = "64055"
      group = "993"
      mode  = "0600"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}

resource "libvirt_domain" "vm" {
  name      = var.vm_name
  type      = "kvm"
  memory    = var.vm_memory_mb
  vcpu      = var.vm_vcpu
  running   = true
  autostart = true

  memory_unit = "Mib"

  os = {
    type         = "hvm"
    type_arch    = var.vm_architecture
    type_machine = "q35"

    boot_devices = [
      {
        dev = "hd"
      },
      {
        dev = "network"
      }
    ]
  }

  devices = {
    disks = [
      {
        device = "disk"

        driver = {
          name = "qemu"
          type = "qcow2"
        }

        source = {
          volume = {
            pool   = var.storage_pool
            volume = libvirt_volume.root.name
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },

      {
        device = "cdrom"

        source = {
          volume = {
            pool   = var.storage_pool
            volume = libvirt_volume.cloudinit.name
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        type = "network"

        model = {
          type = "virtio"
        }

        source = {
          network = {
            network = var.network_name
          }
        }

        wait_for_ip = {
          timeout = var.ip_wait_timeout
          source  = "lease"
        }
      }
    ]
  }
}

data "libvirt_domain_interface_addresses" "vm" {
  domain     = libvirt_domain.vm.name
  source     = "lease"
  depends_on = [libvirt_domain.vm]
}

locals {
  vm_ipv4_addresses = flatten([
    for iface in data.libvirt_domain_interface_addresses.vm.interfaces : [
      for addr in iface.addrs :
      addr.addr if addr.type == "ipv4"
    ]
  ])
}