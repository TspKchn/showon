<FILE:utils.sh>
#!/bin/bash
# =====================================================
# utils.sh - Helper functions for ShowOn
# =====================================================

CONF="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$DEBUG_LOG"
}

load_conf() {
    if [[ -f "$CONF" ]]; then
        source "$CONF"
    else
        log "[ERROR] Config file $CONF not found!"
        exit 1
    fi
}

# safe curl with cookie jar
api_call() {
    local method=$1
    local url=$2
    local data=$3

    if [[ "$method" == "GET" ]]; then
        curl -sk -b /tmp/showon_cookie "$url"
    else
        curl -sk -b /tmp/showon_cookie -H "Content-Type: application/json" \
            -X "$method" "$url" -d "$data"
    fi
}
</FILE:utils.sh>
