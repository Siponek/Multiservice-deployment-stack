#!/bin/sh
#
# Install jq
apt update && apt install jq -y
# Helper functions
#
# Nextcloud
runOCC() {
    php occ "$@"
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

OIDC_CLIENT_SECRET=$(keycloakCurl http://keycloak:8080/admin/realms/vcc/clients/nextcloud | jq -r '.secret')

# Wait until Nextcloud install is complete
until runOCC status --output json_pretty | grep 'installed' | grep -q 'true'; do
    echo 'Nextcloud not ready yet'
    sleep 1
done
echo 'Nextcloud ready'

# Install OpenID Connect login app on Nextcloud
runOCC app:install oidc_login

# Setup OpenID Connect login settings on Nextcloud
setBoolean allow_user_to_change_display_name false
setString lost_password_link disabled
setBoolean oidc_login_disable_registration false

setString oidc_login_provider_url "http://keycloak:8080/realms/vcc"
setString oidc_login_client_id "nextcloud"
setString oidc_login_client_secret "${OIDC_CLIENT_SECRET}"
setBoolean oidc_login_end_session_redirect true
setString oidc_login_logout_url "http://nextcloud/apps/oidc_login/oidc"
setBoolean oidc_login_auto_redirect false
setBoolean oidc_login_redir_fallback true

runOCC config:system:set --value=preferred_username --type=string -- oidc_login_attributes id
runOCC config:system:set --value=email --type=string -- oidc_login_attributes mail
