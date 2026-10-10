variable "libvirt_uri" {
  description = "URI подключение к libvirt."
  type        = string
  default     = "qemu:///system"
}

variable "vm_name" {
  description = "Имя виртуальной машины."
  type        = string
  default     = "apo_lab_vm"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.vm_name))
    error_message = "Имя VM может содержать латинские буквы, цифры, точки, дефисы и подчёркивания."
  }
}

variable "storage_pool" {
  description = "Имя существующего хранилища libvirt."
  type        = string
  default     = "default"
}

variable "network_name" {
  description = "Имя существующей сети libvirt."
  type        = string
  default     = "default"
}

variable "vm_memory_mb" {
  description = "Объём оперативной памяти VM в MiB."
  type        = number
  default     = 4096

  validation {
    condition     = var.vm_memory_mb >= 1024
    error_message = "Память должна составлять не менее 1024 MiB."
  }
}

variable "vm_vcpu" {
  description = "Количество виртуальных процессоров."
  type        = number
  default     = 2

  validation {
    condition     = var.vm_vcpu >= 1 && floor(var.vm_vcpu) == var.vm_vcpu
    error_message = "Количество vCPU должно быть положительным целым числом."
  }
}

variable "vm_disk_size_gib" {
  description = "Размер системного диска VM в GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.vm_disk_size_gib >= 10 && floor(var.vm_disk_size_gib) == var.vm_disk_size_gib
    error_message = "Размер диска должен быть целым числом не менее 10 GiB."
  }
}

variable "vm_architecture" {
  description = "Архитектура гостевой системы."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "aarch64"], var.vm_architecture)
    error_message = "Допустимые значения: x86_64 и aarch64."
  }
}

variable "ubuntu_image_url" {
  description = "URL облачного образа Ubuntu, соответствующего архитектуре VM."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "vm_user" {
  description = "Пользователь Linux для SSH и Ansible."
  type        = string
  default     = "ubuntu"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*[$]?$", var.vm_user))
    error_message = "Указано некорректное имя Linux-пользователя."
  }
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Путь к приватному SSH-ключу, используемому для подключения."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ip_wait_timeout" {
  description = "Время ожидания IPv4-адреса в секундах."
  type        = number
  default     = 300

  validation {
    condition     = var.ip_wait_timeout >= 30 && floor(var.ip_wait_timeout) == var.ip_wait_timeout
    error_message = "Время ожидания должно быть целым числом не менее 30 секунд."
  }
}