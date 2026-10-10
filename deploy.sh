#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
SSH_KEY="${HOME}/.ssh/apo_lab_VM"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Ошибка: приватный SSH-ключ не найден: ${SSH_KEY}" >&2
    exit 1
fi

terraform -chdir="$TERRAFORM_DIR" init

terraform -chdir="$TERRAFORM_DIR" apply

# Получить IP из output Terraform.
if ! VM_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw vm_ipv4)"; then
    echo "Ошибка: Terraform не вернул IP виртуальной машины." >&2
    exit 1
fi

if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
    echo "Ошибка: IP виртуальной машины не найден." >&2
    exit 1
fi

echo "IP виртуальной машины: $VM_IP"

# Сгенерировать inventory.ini с актуальным адресом.
cat > "${ANSIBLE_DIR}/inventory.ini" <<EOF
[app]
lab-vm ansible_host=${VM_IP}

[app:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=${SSH_KEY}
ansible_python_interpreter=/usr/bin/python3
EOF

#  Развернуть приложение.
ansible-playbook \
    -i "${ANSIBLE_DIR}/inventory.ini" \
    "${ANSIBLE_DIR}/playbook.yml"
