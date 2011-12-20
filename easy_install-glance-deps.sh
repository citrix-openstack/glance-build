#!/bin/sh

set -ex

MOCK="$1"

# Dependencies for Glance
$MOCK --chroot "easy_install-2.6 -vvv -H None -f /eggs -z \
                argparse==1.1 \
                pycrypto==2.4.1
"
