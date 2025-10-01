#!/usr/bin/env bash

shopt -s globstar nullglob

for playbook in customize/*.y{a,}ml; do
  echo "Running playbook: $playbook"
  ansible-playbook -i inventory.ini "$playbook"
done
