#!/bin/bash
# Acquire a TLS certificate from Let's Encrypt for Postgres, and replace it
# once it is $ROTATE_AFTER_DAYS days old. Runs forever, started by supervisord.
#
# Configured through the environment of the container:
#   TLS_DOMAIN   hostname to request the certificate for (required; without it
#                this script idles and Postgres keeps its self-signed cert)
#   TLS_EMAIL    contact address for the Let's Encrypt account (optional)
#   TLS_STAGING  set to 1 to use the Let's Encrypt staging environment
#
# The challenge is answered over HTTP by the nginx in this container, so
# http://$TLS_DOMAIN/.well-known/acme-challenge/ has to reach it.
set -u

ROTATE_AFTER_DAYS=30
CERT_NAME="udd-mirror"
CERT="/etc/letsencrypt/live/$CERT_NAME/fullchain.pem"
WEBROOT="/var/www/html"
CHECK_INTERVAL=86400 # how often to look at the age of the certificate
RETRY_INTERVAL=3600  # how long to wait after a failed attempt

if [ -z "${TLS_DOMAIN:-}" ]; then
    echo "TLS_DOMAIN is not set, not requesting a Let's Encrypt certificate."
    exec sleep infinity
fi

cert_age_days() {
    local not_before
    not_before=$(openssl x509 -noout -startdate -in "$CERT" | cut -d= -f2)
    echo $(( ($(date +%s) - $(date -d "$not_before" +%s)) / 86400 ))
}

request_cert() {
    local args=(certonly --non-interactive --agree-tos --force-renewal
                --webroot --webroot-path "$WEBROOT"
                --cert-name "$CERT_NAME" --domain "$TLS_DOMAIN")
    if [ -n "${TLS_EMAIL:-}" ]; then
        args+=(--email "$TLS_EMAIL")
    else
        args+=(--register-unsafely-without-email)
    fi
    if [ "${TLS_STAGING:-}" = 1 ]; then
        args+=(--test-cert)
    fi
    certbot "${args[@]}" && /usr/local/bin/install_pg_cert.sh
}

# Give nginx a moment to come up, it has to answer the challenge.
sleep 10

while true; do
    if [ ! -f "$CERT" ]; then
        echo "No certificate for $TLS_DOMAIN yet, requesting one."
    elif ! openssl x509 -noout -ext subjectAltName -in "$CERT" | grep -qw "DNS:$TLS_DOMAIN"; then
        echo "The certificate is not for $TLS_DOMAIN, requesting a new one."
    elif [ "$(cert_age_days)" -ge "$ROTATE_AFTER_DAYS" ]; then
        echo "The certificate is $(cert_age_days) days old, rotating it."
    else
        echo "The certificate is $(cert_age_days) days old, nothing to do."
        sleep "$CHECK_INTERVAL"
        continue
    fi

    if request_cert; then
        sleep "$CHECK_INTERVAL"
    else
        echo "Requesting a certificate failed, trying again in $RETRY_INTERVAL seconds." >&2
        sleep "$RETRY_INTERVAL"
    fi
done
