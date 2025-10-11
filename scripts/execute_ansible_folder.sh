#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure an argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <folder>"
  exit 1
fi

folder="$1"

# Ensure the folder exists
if [ ! -d "$folder" ]; then
  echo "Error: Folder '$folder' does not exist."
  exit 1
fi

shopt -s nullglob

for playbook in $(find "$folder" -maxdepth 1 -type f -regex '.*/[0-9]?[0-9]-.*\.ya?ml' | sort -V); do
  echo "Running playbook: $playbook"
  ansible-playbook -i inventory.ini "$playbook"
done