#!/usr/bin/env bash
# gpg loopback wrapper: hands the passphrase to gpg on fd 3; never prints it.
: "${GPG_PASSPHRASE:?GPG_PASSPHRASE is not set}"
exec gpg --batch --pinentry-mode loopback --passphrase-fd 3 "$@" 3< <(printf '%s\n' "${GPG_PASSPHRASE}")
