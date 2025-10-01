#!/bin/bash

set -uo pipefail

set +e

echo $DOMAIN_PASS | realm leave --remove

set -e