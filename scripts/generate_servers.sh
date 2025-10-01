#!/usr/bin/env bash
set -euo pipefail

CONTROLPLANE_NODES_COUNT=${CONTROLPLANE_NODES_COUNT:-1}
CONTROLPLANE_MAX_CPUS=${CONTROLPLANE_MAX_CPUS:-2}
CONTROLPLANE_MAX_MEMORY=${CONTROLPLANE_MAX_MEMORY:-2048}

WORKER_NODES_COUNT=${WORKER_NODES_COUNT:-2}
WORKER_MAX_CPUS=${WORKER_MAX_CPUS:-2}
WORKER_MAX_MEMORY=${WORKER_MAX_MEMORY:-2048}

NETWORK_PREFIX=${NETWORK_PREFIX:-192.168.56}

servers=()
controlplane_entries=()
worker_entries=()

j=0
for ((i=0; i<CONTROLPLANE_NODES_COUNT; i++)); do
  if [[ $i -eq 0 ]]; then
    mode="init"
  else
    mode="controlplane"
  fi
  name="kcontrolplane$((i+1))"
  ip="${NETWORK_PREFIX}.20$((j+1))"
  servers+=("$name,$CONTROLPLANE_MAX_MEMORY,$CONTROLPLANE_MAX_CPUS,$ip,$mode")
  controlplane_entries+=("$ip mode=$mode")
  ((j++))
done

for ((i=0; i<WORKER_NODES_COUNT; i++)); do
  name="kworker$((i+1))"
  ip="${NETWORK_PREFIX}.20$((j+1))"
  servers+=("$name,$WORKER_MAX_MEMORY,$WORKER_MAX_CPUS,$ip,worker")
  worker_entries+=("$ip")
  ((j++))
done

# ─────────────────────────────────────
# Output servers to stdout for Jenkins
printf "%s\n" "${servers[@]}"

# ─────────────────────────────────────
# Write Ansible inventory
cat > inventory.ini <<EOF
[controlplane]
$(for entry in "${controlplane_entries[@]}"; do echo "$entry"; done)

[workers]
$(for entry in "${worker_entries[@]}"; do echo "$entry"; done)

[kubernetes:children]
controlplane
workers
EOF
