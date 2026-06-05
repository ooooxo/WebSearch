#!/usr/bin/env bash
# Let's Encrypt 证书检测与复用

letsencrypt_cert_exists() {
    local domain="$1"
    [[ -n "$domain" ]] \
        && [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]] \
        && [[ -f "/etc/letsencrypt/live/${domain}/privkey.pem" ]]
}

letsencrypt_cert_name() {
    local domain="$1"
    local name=""

    if ! command -v certbot >/dev/null 2>&1; then
        echo "$domain"
        return 0
    fi

    name="$(certbot certificates 2>/dev/null | awk -v d="$domain" '
        /Certificate Name:/ { cert=$3 }
        $0 ~ d { if (cert != "") { print cert; exit } }
    ')"

    if [[ -n "$name" ]]; then
        echo "$name"
        return 0
    fi

    if letsencrypt_cert_exists "$domain"; then
        echo "$domain"
    fi
}
