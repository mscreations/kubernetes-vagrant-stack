#!/bin/bash

set -uo pipefail

set +e
umount /mnt/k8s-data

echo $DOMAIN_PASS | realm leave --remove

systemctl poweroff