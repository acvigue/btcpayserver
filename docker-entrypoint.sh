#!/usr/bin/env bash
set -euo pipefail

echo "$(/sbin/ip route|awk '/default/ { print $3 }')  host.docker.internal" >> /etc/hosts

ensure_owned_dir() {
    local target_dir="$1"
    if [ -n "${target_dir}" ]; then
        mkdir -p "${target_dir}"
        chown -R btcpayserver:btcpayserver "${target_dir}"
    fi
}

# Ensure data and plugin directories are writable before dropping privileges.
ensure_owned_dir "${BTCPAY_DATADIR:-}"
ensure_owned_dir "/home/btcpayserver/.btcpayserver"
ensure_owned_dir "/home/btcpayserver/.btcpayserver/Plugins"

if [ -f "${BTCPAY_SSHAUTHORIZEDKEYS:-}" ] && [[ -n "${BTCPAY_SSHKEYFILE:-}" ]]; then
    if ! [ -f "${BTCPAY_SSHKEYFILE}" ] || ! [ -f "${BTCPAY_SSHKEYFILE}.pub" ]; then
        rm -f "${BTCPAY_SSHKEYFILE}" "${BTCPAY_SSHKEYFILE}.pub"
        echo "Creating BTCPay Server SSH key File..."
        ssh-keygen -t ed25519 -f "${BTCPAY_SSHKEYFILE}" -q -P "" -m PEM -C btcpayserver > /dev/null
        # Let's make sure the SSHAUTHORIZEDKEYS doesn't have our key yet
        # Because the file is mounted, set -i does not work
        sed '/btcpayserver$/d' "${BTCPAY_SSHAUTHORIZEDKEYS}" > "${BTCPAY_SSHAUTHORIZEDKEYS}.new"
        cat "${BTCPAY_SSHAUTHORIZEDKEYS}.new" > "${BTCPAY_SSHAUTHORIZEDKEYS}"
        rm -rf "${BTCPAY_SSHAUTHORIZEDKEYS}.new"
    fi

    if [ -f "${BTCPAY_SSHKEYFILE}.pub" ] && \
       ! grep -q "btcpayserver$" "${BTCPAY_SSHAUTHORIZEDKEYS}"; then
        echo "Adding BTCPay Server SSH key to authorized keys"
        cat "${BTCPAY_SSHKEYFILE}.pub" >> "${BTCPAY_SSHAUTHORIZEDKEYS}"
    fi
fi

exec su-exec btcpayserver:btcpayserver dotnet BTCPayServer.dll
