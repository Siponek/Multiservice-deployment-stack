#!/bin/sh
#
# Helper functions
#
# Nextcloud
runOCC() {
    docker exec -i -u www-data "$NC_CONTAINER_NAME" php occ "$@"
}
setBoolean() { runOCC config:system:set --value="$2" --type=boolean -- "$1"; }
setInteger() { runOCC config:system:set --value="$2" --type=integer -- "$1"; }
setString() { runOCC config:system:set --value="$2" --type=string -- "$1"; }
# Keycloak
runKeycloak() {
    docker exec -i "$KC_CONTAINER_NAME" "$@"
}
keycloakAdminToken() {
    runKeycloak curl -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
        --data-urlencode "username=${KEYCLOAK_USERNAME}" \
        --data-urlencode "password=${KEYCLOAK_PASSWORD}" \
        --data-urlencode 'grant_type=password' \
        --data-urlencode 'client_id=admin-cli'
}
keycloakCurl() {
    runKeycloak curl \
        --header "Authorization: Bearer $(keycloakAdminToken | jq -r '.access_token')" \
        "$@"
}

# Wait until Nextcloud container appears
until docker inspect "$NC_CONTAINER_NAME"; do
    sleep 1
done
echo 'Nextcloud container found'

# Wait until Keycloak container appears
until docker inspect "$KC_CONTAINER_NAME"; do
    sleep 1
done
echo 'Keycloak container found'

# Wait until Keycloak is alive
until runKeycloak curl -sSf http://127.0.0.1:8080; do
    sleep 1
done
echo 'Keycloak alive'

OIDC_CLIENT_SECRET=$(keycloakCurl http://127.0.0.1:8080/admin/realms/vcc/clients/nextcloud | jq -r '.secret')

# print the OIDC_CLIENT_SECRET
echo "OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET}"

# Wait until Nextcloud install is complete
until runOCC status --output json_pretty | grep 'installed' | grep -q 'true'; do
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
setBoolean oidc_login_auto_redirect true
setBoolean oidc_login_redir_fallback true

runOCC config:system:set --value=preferred_username --type=string -- oidc_login_attributes id
runOCC config:system:set --value=email --type=string -- oidc_login_attributes mail
