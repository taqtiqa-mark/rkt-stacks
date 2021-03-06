#!/usr/bin/env bash
#
# Copyright (C) 2018 TAQTIQA LLC. <http://www.taqtiqa.com>
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU Affero General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU Affero General Public License v3
#along with this program.
#If not, see <https://www.gnu.org/licenses/agpl-3.0.en.html>.
#

# Sign a file with a single use private key and password using GPG 1
#
# Usage: sign-once <pub-key-prefix> <file>
#
# FEATURES:
# - Signatures use one off private key, public key is a build artifact.
#
# NOTE: to generate a public/private key use the following commands:
#

set -exuo pipefail

PREFIX=$1
FILENAME=$2

if [[ $# -lt 2 ]] ; then
  echo "Usage: sign-once <pub-key-prefix> <file>"
  exit 1
fi

function signonceend() {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      rm -f ${PUBLICKEY_FILENAME}
      rm -f ${SIGNATURE_FILENAME}
    fi
    rm -f ${TMP_PRIVATE_KEYRING}
    rm -f ${TMP_PUBLIC_KEYRING}
    exit $EXIT
}

trap signonceend EXIT

TMP_PRIVATE_KEYRING=./scripts/rkt.sec
TMP_PUBLIC_KEYRING=./scripts/rkt.pub

PUBLICKEY_FILENAME="./${PREFIX}-signoncekey-public.asc"
SIGNATURE_FILENAME="${FILENAME}.asc"

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

pushd ${dir}
  pushd ..
    # Create private and public keys
    gpg --batch --gen-key ./scripts/gpg-batch
    KEY_ID=$(gpg --no-tty --no-default-keyring --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --no-auto-check-trustdb --list-keys --with-colons|grep pub|cut -d':' -f5)
    echo -e "trust\n5\ny\n" | gpg --command-fd 0 --edit-key ${KEY_ID}
    # Export public key
    gpg --no-default-keyring --armor \
    --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} \
    --export ${KEY_ID} >${PUBLICKEY_FILENAME}
    # Sign file
    echo -e "rkt\n"|gpg --passphrase-fd 0 --trust-model always --no-default-keyring --armor --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --output ${SIGNATURE_FILENAME} --detach-sig ${FILENAME}
    # Verify file
    gpg --trust-model always --no-default-keyring \
    --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} \
    --verify ${SIGNATURE_FILENAME} ${FILENAME}

    rm -f ${TMP_PRIVATE_KEYRING}
    rm -f ${TMP_PUBLIC_KEYRING}
  popd
popd