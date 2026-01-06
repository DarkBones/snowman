set -euo pipefail

nmNamespace="$1"
connectionsDir="$2"
netListFile="$3"

mkdir -p "$connectionsDir"
chmod 0700 "$connectionsDir"
chown root:root "$connectionsDir"

uuidgen_bin="$(command -v uuidgen)"
systemctl_bin="$(command -v systemctl)"

write_conn() {
    local netName="$1"
    local ssid="$2"
    local pskFile="$3"

    local file="$connectionsDir/snowman-$netName.nmconnection"
    local uuid="$("$uuidgen_bin" --sha1 --namespace "$nmNamespace" --name "$netName")"

    local security_block=""
    if [[ -n "$pskFile" && -r "$pskFile" ]]; then
        local psk
        psk="$(cat "$pskFile")"
        security_block=$(
            printf '%s\n' \
                '[wifi-security]' \
                'key-mgmt=wpa-psk' \
                "psk=$psk"
        )
    fi

    local tmp
    tmp="$(mktemp)"

    {
        printf '%s\n' \
            '[connection]' \
            "id=snowman-$netName" \
            "uuid=$uuid" \
            'type=wifi' \
            'autoconnect=true' \
            '' \
            '[wifi]' \
            'mode=infrastructure' \
            "ssid=$ssid" \
            ''
        if [[ -n "$security_block" ]]; then
            printf '%s\n\n' "$security_block"
        fi
        printf '%s\n' \
            '[ipv4]' \
            'method=auto' \
            '' \
            '[ipv6]' \
            'method=ignore'
    } >"$tmp"

    install -m 0600 -o root -g root "$tmp" "$file"
    rm -f "$tmp"
}

while IFS=$'\t' read -r netName ssid pskFile; do
    [[ -z "$netName" ]] && continue
    write_conn "$netName" "$ssid" "$pskFile"
done <"$netListFile"

"$systemctl_bin" try-reload-or-restart NetworkManager.service >/dev/null 2>&1 || true
