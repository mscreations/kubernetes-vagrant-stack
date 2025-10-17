#!/bin/bash

set -uo pipefail

set +e
kubeadm reset -f

umount /mnt/k8s-data

echo $DOMAIN_PASS | realm leave --remove
