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
# NOTE: jq package is required!
#

METHOD="$1"
CLIENTMAC="$2"

# Path to your JSON file
json_file="/etc/nodogsplash/users.json"

# Check if the JSON file exists
if [ ! -f "$json_file" ]; then
    echo "JSON file not found: $json_file"
    exit 1
fi

case "$METHOD" in
auth_client)
    USERNAME="$3"
    PASSWORD="$4"

    # Check if the provided username and password match any entry in the JSON file
    for user in $(jq -c '.[]' "$json_file"); do
        usern=$(echo "$user" | jq -r '.username')
        passw=$(echo "$user" | jq -r '.password')
        usrtimeout=$(echo "$user" | jq -r '.timeout')
        usrupload=$(echo "$user" | jq -r '.uploadLimitBytes // 0')
        usrdownload=$(echo "$user" | jq -r '.downloadLimitBytes // 0')
        echo "User: $usern"
        echo "Timeout: $usrtimeout"
        echo "Upload Limit (bytes): $usrupload"
        echo "Download Limit (bytes): $usrdownload"
        echo ""
        if [ "$USERNAME" = "$usern" ] && [ "$PASSWORD" = "$passw" ]; then
            echo "Logged in as $usern!"
            echo $usrtimeout $usrupload $usrdownload
            exit 0
        fi
    done
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
