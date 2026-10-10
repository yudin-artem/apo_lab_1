output "vm_name" {
  description = "Имя виртуальной машины."
  value       = libvirt_domain.vm.name
}

output "vm_ipv4" {
  description = "Первый обнаруженный IPv4-адрес VM."
  value       = try(local.vm_ipv4_addresses[0], null)
}

output "ssh_command" {
  description = "Команда для подключения к виртуальной машине."
  value = format(
    "ssh -i %s %s@%s",
    pathexpand(var.ssh_private_key_path),
    var.vm_user,
    try(local.vm_ipv4_addresses[0], "IP_NOT_FOUND")
  )
}