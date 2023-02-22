#!/bin/sh
#
# Helper functions
#
# Nextcloud
runOCC() {
    sudo -u www-data php -d memory_limit=512M occ "$@"
}
setBoolean() { runOCC config:system:set --value="$2" --type=boolean -- "$1"; }
setInteger() { runOCC config:system:set --value="$2" --type=integer -- "$1"; }
setString() { runOCC config:system:set --value="$2" --type=string -- "$1"; }
# Keycloak
keycloakAdminToken() {
    curl -X POST "http://keycloak:8080/realms/master/protocol/openid-connect/token" \
        --data-urlencode "username=${KEYCLOAK_USERNAME}" \
        --data-urlencode "password=${KEYCLOAK_PASSWORD}" \
        --data-urlencode 'grant_type=password' \
        --data-urlencode 'client_id=admin-cli'
}
keycloakCurl() {
    curl \
        --header "Authorization: Bearer $(keycloakAdminToken | jq -r '.access_token')" \
        "$@"
}

# Wait until Keycloak is alive
until curl -sSf http://keycloak:8080; do
    sleep 1
done
echo 'Keycloak alive'

/entrypoint.sh apache2-foreground &

# OIDC_CLIENT_SECRET=$(keycloakCurl http://keycloak:8080/admin/realms/vcc/clients/nextcloud | jq -r '.secret')

# Wait until Nextcloud install is complete
until runOCC status --output json_pretty | grep "installed" | grep -q "true"; do
    echo 'Nextcloud not ready yet'
    sleep 1
done
echo 'Nextcloud ready'

# Install OpenID Connect login app on Nextcloud
runOCC app:install oidc_login

# Setup OpenID Connect login settings on Nextcloud

runOCC config:system:set trusted_domains 1 --value="192.168.50.10"
runOCC config:system:set trusted_domains 2 --value="cloud.local"

setBoolean allow_user_to_change_display_name false
setString lost_password_link disabled   
setBoolean oidc_login_disable_registration false
setString oidc_login_provider_url "${OIDC_PROVIDER_URL}"
setString oidc_login_client_id "${OIDC_CLIENT_ID}"
setBoolean oidc_login_end_session_redirect true
setString oidc_login_client_secret "${OIDC_CLIENT_SECRET}"
setString oidc_login_logout_url "${OIDC_LOGOUT_URL}"
setBoolean oidc_login_auto_redirect true
setBoolean oidc_login_redir_fallback true
setBoolean oidc_login_tls_verify false

runOCC config:system:set --value=preferred_username --type=string -- oidc_login_attributes id
runOCC config:system:set --value=email --type=string -- oidc_login_attributes mail

tail -f /dev/null
