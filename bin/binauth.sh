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

# Local logging to /tmp/nodogsplash
LOG_DIR="/tmp/nodogsplash"
LOG_FILE="$LOG_DIR/binauth.log"
# CSV auth log config
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-21}"
LOGGED_USERS_PREFIX="${LOGGED_USERS_PREFIX:-$LOG_DIR/logged_users}"
LOGGED_USERS_FILE="${LOGGED_USERS_FILE:-$LOG_DIR/logged_users.csv}"
mkdir -p "$LOG_DIR" 2>/dev/null || true
log_msg() {
    # Avoid logging secrets; never log passwords
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$METHOD] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Rotate CSV logs older than retention period
rotate_logs() {
    find "$LOG_DIR" -maxdepth 1 -type f -name "$(basename "$LOGGED_USERS_PREFIX")-*.csv" -mtime +"$LOG_RETENTION_DAYS" -exec rm -f {} + 2>/dev/null || true
}

# Append successful authentication to daily CSV and update latest pointer
log_auth_csv() {
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    mac="$1"; user="$2"; pass="$3"
    csv_file="${LOGGED_USERS_PREFIX}-$(date +%F).csv"
    # Ensure directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    # Ensure header
    if [ ! -f "$csv_file" ]; then
        echo "timestamp,mac,username,password" > "$csv_file" 2>/dev/null || true
    fi
    echo "$ts,$mac,$user,$pass" >> "$csv_file" 2>/dev/null || true
    # Update pointer file
    ln -sf "$csv_file" "$LOGGED_USERS_FILE" 2>/dev/null || cp "$csv_file" "$LOGGED_USERS_FILE" 2>/dev/null || true
    # Cleanup old CSVs
    rotate_logs
}

# Users API endpoint (override with $API_URL if needed)
API_URL="${API_URL:-https://ugly-kordula-cornedpotato69-46ad695b.koyeb.app/api/users}"
# Local fallback JSON file (override with $USERS_JSON if needed)
USERS_JSON="${USERS_JSON:-/etc/nodogsplash/users.json}"

# Obtain users list: try API first, then fallback to local file
users_json=""
api_resp=$(curl -sf --connect-timeout 2 --max-time 5 "$API_URL" 2>/dev/null)
if [ $? -eq 0 ] && echo "$api_resp" | jq -e 'type == "array"' >/dev/null 2>&1; then
    users_json="$api_resp"
else
    logger -t nds-binauth "API unavailable or invalid JSON; trying fallback file $USERS_JSON"
    log_msg "API unavailable or invalid JSON; trying fallback file $USERS_JSON"
    if [ -f "$USERS_JSON" ]; then
        file_resp=$(cat "$USERS_JSON")
        if echo "$file_resp" | jq -e 'type == "array"' >/dev/null 2>&1; then
            users_json="$file_resp"
            logger -t nds-binauth "Using local users.json fallback"
            log_msg "Using local users.json fallback"
        fi
    fi
fi

if [ -z "$users_json" ]; then
    echo "Authentication error: user service and local fallback unavailable"
    logger -t nds-binauth "No users available from API or file"
    log_msg "No users available from API or file"
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

    # Normalize and validate CLIENTMAC (uppercase)
    NORM_MAC=$(echo "$CLIENTMAC" | tr '[:lower:]' '[:upper:]')

    log_msg "MAC provided by client: $NORM_MAC"

    # Note: MAC is mandatory, but a user's macAddress of null/blank means no binding; allow in that case.

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

        # Validation
        if [ "$USERNAME" = "$usern" ] && [ "$PASSWORD" = "$passw" ]; then
            log_msg "User '$usern' matched!"
            # Accept if account has no MAC binding (null/blank) or matches provided MAC
            if [ -z "$usermac" ] || [ "$NORM_MAC" = "$usermac" ]; then
                echo "Logged in as $usern (MAC validated)"
                echo $usrtimeout $usrupload $usrdownload
                log_msg "Authenticated '$usern' with MAC $NORM_MAC, timeout=$usrtimeout up=$usrupload down=$usrdownload"
                # CSV log (timestamp,mac,username,password) and rotate
                log_auth_csv "$NORM_MAC" "$USERNAME" "$PASSWORD"
                exit 0
            else
                FOUND_MATCH=1
                log_msg "User '$usern' password ok but MAC mismatch (client=$NORM_MAC, account=$usermac)"
                continue
            fi
        fi
    done
    if [ $FOUND_MATCH -eq 1 ]; then
        echo "Access denied: MAC address does not match account"
        logger -t nds-binauth "Denied $USERNAME from $NORM_MAC: MAC mismatch"
        log_msg "Denied '$USERNAME' from $NORM_MAC: MAC mismatch"
    fi
    # Deny client access to the Internet.
    log_msg "Authentication failed for '$USERNAME'"
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
