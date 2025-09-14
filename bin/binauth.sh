#!/bin/sh

# It verifies a client username and password and sets the session length.
#
# If BinAuth is enabled, NDS will call this script as soon as it has received an authentication request
# from the web page served to the client's CPD (Captive Portal Detection) Browser by one of the following:
#
# 1. splash_sitewide.html
# 2. PreAuth
# 3. FAS
#
# The username and password entered by the client user will be included in the query string sent to NDS via html GET
# For an example, see the file splash_sitewide.html
#
# REQUIREMENTS: jq, curl
#

METHOD="$1"
ARG2="$2"
ARG3="$3"

# Users API endpoint (override with $API_URL if needed)
API_URL="${API_URL:-http://127.0.0.1:3000/api/users}"
# Local fallback JSON file (override with $USERS_JSON if needed)
USERS_JSON="${USERS_JSON:-/etc/nodogsplash/users.json}"

# Obtain users list: try API first, then fallback to local file
users_json=""
api_resp=$(curl -sf --connect-timeout 2 --max-time 5 "$API_URL" 2>/dev/null)
if [ $? -eq 0 ] && echo "$api_resp" | jq -e 'type == "array"' >/dev/null 2>&1; then
    users_json="$api_resp"
else
    logger -t nds-binauth "API unavailable or invalid JSON; trying fallback file $USERS_JSON"
    if [ -f "$USERS_JSON" ]; then
        file_resp=$(cat "$USERS_JSON")
        if echo "$file_resp" | jq -e 'type == "array"' >/dev/null 2>&1; then
            users_json="$file_resp"
            logger -t nds-binauth "Using local users.json fallback"
        fi
    fi
fi

if [ -z "$users_json" ]; then
    echo "Authentication error: user service and local fallback unavailable"
    logger -t nds-binauth "No users available from API or file"
    exit 1
fi

case "$METHOD" in
auth_client)
    # Determine argument order: some setups pass MAC as 3rd arg.
    # Prefer $3 if it looks like a MAC, otherwise use $2.
    if echo "$ARG3" | grep -Eq '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$'; then
        CLIENTMAC="$ARG3"
        USERNAME="$4"
        PASSWORD="$5"
    else
        CLIENTMAC="$ARG2"
        USERNAME="$3"
        PASSWORD="$4"
    fi

    # Normalize CLIENTMAC (uppercase)
    NORM_MAC=$(echo "$CLIENTMAC" | tr '[:lower:]' '[:upper:]')
    MAC_PROVIDED=0
    if [ -n "$NORM_MAC" ] && [ "$NORM_MAC" != "UNKNOWN" ]; then
        MAC_PROVIDED=1
    fi

    # If MAC provided, require it to exist in records (any user)
    if [ $MAC_PROVIDED -eq 1 ]; then
        echo "$users_json" | jq -e --arg mac "$NORM_MAC" 'map((.macAddress // null) | select(. != null) | ascii_upcase) | index($mac)' >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Access denied: device MAC not registered"
            logger -t nds-binauth "Denied $USERNAME from $NORM_MAC: MAC not registered"
            exit 1
        fi
    fi

    # Check if the provided username and password match any entry from server response
    FOUND_MATCH=0
    for user in $(echo "$users_json" | jq -c '.[]'); do
        usern=$(echo "$user" | jq -r '.username')
        passw=$(echo "$user" | jq -r '.password')
        usermac=$(echo "$user" | jq -r '(.macAddress // "")' | tr '[:lower:]' '[:upper:]')
        usrtimeout=$(echo "$user" | jq -r '.timeout')
        # Support both ...Bytes and ...Bites (UI uses Bites)
        usrupload=$(echo "$user" | jq -r '(.uploadLimitBytes // .uploadLimitBites // 0)')
        usrdownload=$(echo "$user" | jq -r '(.downloadLimitBytes // .downloadLimitBites // 0)')
        echo "User: $usern"
        echo "Mac Address (record): $usermac"
        echo "Timeout: $usrtimeout"
        echo "Upload Limit (bytes): $usrupload"
        echo "Download Limit (bytes): $usrdownload"
        echo ""

        # Validation
        if [ "$USERNAME" = "$usern" ] && [ "$PASSWORD" = "$passw" ]; then
            if [ $MAC_PROVIDED -eq 1 ]; then
                if [ -n "$usermac" ] && [ "$NORM_MAC" = "$usermac" ]; then
                    echo "Logged in as $usern (MAC validated)"
                    echo $usrtimeout $usrupload $usrdownload
                    exit 0
                else
                    FOUND_MATCH=1
                    continue
                fi
            else
                echo "Logged in as $usern!"
                echo $usrtimeout $usrupload $usrdownload
                exit 0
            fi
        fi
    done
    if [ $MAC_PROVIDED -eq 1 ] && [ $FOUND_MATCH -eq 1 ]; then
        echo "Access denied: MAC address does not match account"
        logger -t nds-binauth "Denied $USERNAME from $NORM_MAC: MAC mismatch"
    fi
    # Deny client access to the Internet.
    exit 1
    ;;
client_auth | client_deauth | idle_deauth | timeout_deauth | ndsctl_auth | ndsctl_deauth | shutdown_deauth)
    INGOING_BYTES="$3"
    OUTGOING_BYTES="$4"
    SESSION_START="$5"
    SESSION_END="$6"
    # client_auth: Client authenticated via this script.
    # client_deauth: Client deauthenticated by the client via splash page.
    # idle_deauth: Client was deauthenticated because of inactivity.
    # timeout_deauth: Client was deauthenticated because the session timed out.
    # ndsctl_auth: Client was authenticated by the ndsctl tool.
    # ndsctl_deauth: Client was deauthenticated by the ndsctl tool.
    # shutdown_deauth: Client was deauthenticated by Nodogsplash terminating.
    ;;
esac
