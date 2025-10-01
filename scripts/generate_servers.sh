#!/usr/bin/env bash

export CONTROLPLANE_NODES_COUNT=${CONTROLPLANE_NODES_COUNT}
export CONTROLPLANE_MAX_CPUS=${CONTROLPLANE_MAX_CPUS}
export CONTROLPLANE_MAX_MEMORY=${CONTROLPLANE_MAX_MEMORY}
export WORKER_NODES_COUNT=${WORKER_NODES_COUNT}
export WORKER_MAX_CPUS=${WORKER_MAX_CPUS}
export WORKER_MAX_MEMORY=${WORKER_MAX_MEMORY}
export NETWORK_PREFIX=${NETWORK_PREFIX}

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
  controlplane_entries+=("$name mode=$mode")
  ((j++))
done

for ((i=0; i<WORKER_NODES_COUNT; i++)); do
  name="kworker$((i+1))"
  ip="${NETWORK_PREFIX}.20$((j+1))"
  servers+=("$name,$WORKER_MAX_MEMORY,$WORKER_MAX_CPUS,$ip,worker")
  worker_entries+=("$name")
  ((j++))
done

# Output servers to stdout for Jenkins
printf "%s\n" "${servers[@]}"

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
