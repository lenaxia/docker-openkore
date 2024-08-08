#!/bin/sh
#
# This entrypoint script creates a OpenKore instance prepared to use a random, unused account and character.
# If the enviroment variable OK_USERNAMEMAXSUFFIX is set, the script will connect to the rAthena database
# and retrieve query accounts matching OK_USERNAME plus 0...n number sequence. If the character happen to
# be already online, then skips to the next username.
#
# Variable description:
# ====================
# OK_IP="IP address of the Ragnarok Online server"
# OK_USERNAME="Account username"
# OK_PWD="Account password"
# OK_CHAR="Character slot. Default: 0"
# OK_LOCKMAP="prt_fld07"
# OK_USERNAMEMAXSUFFIX="Maximum number of suffixes to generate with the username."
# OK_KILLSTEAL="It is ok that the bot attacks monster that are already being attacked by other players."
# OK_FOLLOW_USERNAME1="Name of the username to follow with 20% probability"
# OK_FOLLOW_USERNAME2="Name of a second username to follow with 20% probability"
# MYSQL_HOST="Hostname of the MySQL database. Ex: calnus-beta.mysql.database.azure.com."
# MYSQL_DB="Name of the MySQL database."
# MYSQL_USER="Database username for authentication."
# MYSQL_PWD="Password for authenticating with database. WARNING: it will be visible from Azure Portal."

echo "rAthena Development Team presents"
echo "           ___   __  __"
echo "     _____/   | / /_/ /_  ___  ____  ____ _"
echo "    / ___/ /| |/ __/ __ \/ _ \/ __ \/ __  /"
echo "   / /  / ___ / /_/ / / /  __/ / / / /_/ /"
echo "  /_/  /_/  |_\__/_/ /_/\___/_/ /_/\__,_/"
echo ""
echo "http://rathena.org/board/"
echo ""
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "Initalizing Docker container..."

if [ -z "${OK_IP}" ]; then echo "Missing OK_IP environment variable. Unable to continue."; exit 1; fi
if [ -z "${OK_USERNAME}" ]; then echo "Missing OK_USERNAME environment variable. Unable to continue."; exit 1; fi
if [ -z "${OK_PWD}" ]; then echo "Missing OK_PWD environment variable. Unable to continue."; exit 1; fi

if [ -z "${OK_SERVER}" ]; then OK_SERVER="localHost - rA/Herc"; fi
if [ -z "${OK_CHAR}" ]; then OK_CHAR=0; fi
if [ -z "${OK_LOCKMAP}" ]; then OK_LOCKMAP="prt_flid07"; fi

if [ -z "${OK_ADDTABLEFOLDERS}" ]; then OK_ADDTABLEFOLDERS="kRO/RagexeRE_2020_04_01b;translated/kRO_english"; fi
if [ -z "${OK_MASTER_VERSION}" ]; then OK_MASTER_VERSION="1"; fi
if [ -z "${OK_VERSION}" ]; then OK_VERSION="128"; fi
if [ -z "${OK_CHARBLOCKSIZE}" ]; then OK_CHARBLOCKSIZE="155"; fi
if [ -z "${OK_SERVER_TYPE}" ]; then OK_SERVER_TYPE="kRO_RagexeRE_2020_04_01b"; fi

if [ -z "${REDIS_HOST}" ]; then echo "Missing REDIS_HOST environment variable. Unable to continue."; exit 1; fi
if [ -z "${REDIS_PORT}" ]; then REDIS_PORT=6379; fi
if [ -z "${REDIS_PASSWORD}" ]; then echo "Missing REDIS_PASSWORD environment variable. Unable to continue. If no password use \"\""; exit 1; fi
if [ -z "${LOCK_TIMEOUT}" ]; then LOCK_TIMEOUT=60; fi
LOCK_KEY="openkore_account_lock:${OK_IP}"

if [ "${OK_KILLSTEAL}" = "1" ]; then
    sed -i "1507s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1534s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1571s|return !objectIsMovingTowardsPlayer(\$monster);|return 1;|" /opt/openkore/src/Misc.pm
    sed -i "1583s|return 0|return 1|" /opt/openkore/src/Misc.pm
fi

if [ ! -z "${OK_CONFIG_OVERRIDE_URL}" ]; then
    echo "Downloading config tarball from ${OK_CONFIG_TARBALL_URL}"
    wget -O /tmp/config.tar.gz "${OK_CONFIG_TARBALL_URL}"
    tar -xzf /tmp/config.tar.gz -C /opt/openkore/control/class/
    rm /tmp/config.tar.gz
fi

# Check if Redis is available
echo "Attempting to connect to Redis at ${REDIS_HOST}:${REDIS_PORT}"
redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" PING >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Unable to connect to Redis at $REDIS_HOST:$REDIS_PORT. Falling back to no locking mechanism."
    USE_REDIS_LOCK=false
else
    echo "Successfully connected to Redis"
    USE_REDIS_LOCK=true
fi

if [ -z "${OK_USERNAMEMAXSUFFIX}" ]; then
    sed -i "s|^username.*|username ${OK_USERNAME}|g" /opt/openkore/control/config.txt
else
    if [ -z "${MYSQL_HOST}" ]; then echo "Missing MYSQL_HOST environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_DB}" ]; then echo "Missing MYSQL_DB environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_USER}" ]; then echo "Missing MYSQL_USER environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_PWD}" ]; then echo "Missing MYSQL_PWD environment variable. Unable to continue."; exit 1; fi
    while [ "$LOCK_ACQUIRED" != "OK" ]; do
        for i in `seq 0 ${OK_USERNAMEMAXSUFFIX}`;
        do
            sleep $((RANDOM % 2))
            USERNAME=${OK_USERNAME}${i}
            echo "Querying account ${USERNAME}"

            MYSQL_ACCOUNT_ID_QUERY="SELECT \`account_id\` FROM \`login\` WHERE userid='${USERNAME}';"
            ACCOUNT_ID=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_ACCOUNT_ID_QUERY}");
            MYSQL_CHAR_NAME_QUERY="SELECT \`name\` FROM \`char\` WHERE account_id='${ACCOUNT_ID}' AND char_num='${OK_CHAR}';"
            CHAR_NAME=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_CHAR_NAME_QUERY}");

            if [ -z "${CHAR_NAME}" ]; then echo "Logged in, but no character found in configured slot."; exit 1; fi

            MYSQL_QUERY="SELECT \`online\` FROM \`char\` WHERE account_id='${ACCOUNT_ID}' AND char_num='${OK_CHAR}';"
            CHAR_IS_ONLINE=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}");

            if [ "${CHAR_IS_ONLINE}" = "0" ]; then
                # Attempt to acquire the lock
                LOCK_KEY="openkore_account_lock:${OK_IP}:${ACCOUNT_ID}:${CHAR_NAME}"
                LOCK_ACQUIRED=$(redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" SET "$LOCK_KEY" "$HOSTNAME" NX EX "$LOCK_TIMEOUT")

                if [ "$LOCK_ACQUIRED" = "OK" ]; then
                    # Lock acquired, proceed with account selection
                    echo "Redis lock acquired for account ${USERNAME} (${ACCOUNT_ID}), character ${CHAR_NAME}, lock_key: ${LOCK_KEY}"

                    # With Redis no need to mark char online before logging on
                    #MYSQL_QUERY="UPDATE \`char\` SET \`online\`=1 WHERE account_id='${ACCOUNT_ID}' AND char_num='${OK_CHAR}'"
                    #mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}"

                    CLASS=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "SELECT class FROM \`char\` WHERE char_num='${OK_CHAR}' AND account_id='${ACCOUNT_ID}';")

                    printf "Selected username %s (%s) (%s)\n" "${USERNAME}" "${CHAR_NAME}" "${CLASS}"
                    case ${CLASS} in
                        4) # ACOLYTE
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/acolyte.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto -1|g" /opt/openkore/control/config.txt
                            ;;
                        8) # PRIEST
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/priest.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto -1|g" /opt/openkore/control/config.txt
                            ;;
                        15) # MONK
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/monk.txt /opt/openkore/control/config.txt
                            ;;
                        5) # Merchant
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/merchant.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        10) # Blacksmith
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/blacksmith.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        2) # MAGE
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/mage.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        9) # WIZARD
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/wizard.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 1|g" /opt/openkore/control/config.txt
                            ;;
                        16) # SAGE
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/sage.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 1|g" /opt/openkore/control/config.txt
                            ;;
                        3) # Archer
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/archer.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        11) # Hunter
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/hunter.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        1) # SWORDMAN
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/swordman.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                        7) # KNIGHT
                            mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                            cp /opt/openkore/control/class/knight.txt /opt/openkore/control/config.txt
                            sed -i "s|^attackAuto.*|attackAuto 2|g" /opt/openkore/control/config.txt
                            ;;
                    esac
                    sed -i "s|^username.*|username ${USERNAME}|g" /opt/openkore/control/config.txt

                    # Start a background process to refresh the lock
                    (
                        while true; do
                            redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" EXPIRE "$LOCK_KEY" "$LOCK_TIMEOUT"
                            sleep "$((LOCK_TIMEOUT / 2))"  # Refresh lock every half of the expiration time
                        done
                    ) &
                    LOCK_REFRESH_PID=$!

                    # Start a background process to release the lock on termination signals/events
                    (
                        trap 'redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" DEL "$LOCK_KEY"; exit' SIGTERM SIGKILL TERM
                        while true; do
                            sleep 60  # Sleep for a minute, adjust as needed
                        done
                    ) &
                    LOCK_RELEASE_PID=$!

                    break
                else
                    # Lock not acquired, try the next account
                    echo "Failed to acquire Redis lock for account ${USERNAME} (${ACCOUNT_ID}), lock_key: ${LOCK_KEY}"
                    continue
                fi
            fi
        done
        SLEEP=$((10 + RANDOM % 5))
        if ! [ "$LOCK_ACQUIRED" = "OK" ]; then echo "Failed to acquire lock on any accounts, sleeping for ${SLEEP} then restarting search"; fi
        sleep $SLEEP
    done
fi
sed -i "s|^master$|master ${OK_SERVER}|g" /opt/openkore/control/config.txt
sed -i "s|^server.*|server 0|g" /opt/openkore/control/config.txt
sed -i "s|^password$|password ${OK_PWD}|g" /opt/openkore/control/config.txt
sed -i "s|^char$|char ${OK_CHAR}|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponse 0$|autoResponse 1|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponseOnHeal 0$|autoResponseOnHeal 1|g" /opt/openkore/control/config.txt
sed -i "s|^route_randomWalk_inTown 0$|route_randomWalk_inTown 1|g" /opt/openkore/control/config.txt
sed -i "s|^partyAuto.*|partyAuto 2|g" /opt/openkore/control/config.txt
sed -i "s|^follow 0$|follow 1|g" /opt/openkore/control/config.txt
sed -i "s|^followSitAuto 0$|followSitAuto 1|g" /opt/openkore/control/config.txt
sed -i "s|^attackAuto_inLockOnly 1$|attackAuto_inLockOnly 0|g" /opt/openkore/control/config.txt
sed -i "/pauseCharServer.*/i\pauseCharLogin 2" /opt/openkore/control/config.txt # Add this to pause at login to avoid "Incoming data left in the buffer" issue

sed -i "s|^lockMap$|lockMap ${OK_LOCKMAP}|g" /opt/openkore/control/config.txt
#sed -i "s|^lockMap_x$|lockMap_x 218|g" /opt/openkore/control/config.txt
#sed -i "s|^lockMap_y$|lockMap_y 185|g" /opt/openkore/control/config.txt
#sed -i "s|^lockMap_randX$|lockMap_randX 115|g" /opt/openkore/control/config.txt
#sed -i "s|^lockMap_randY$|lockMap_randY 20|g" /opt/openkore/control/config.txt

sed -i "s|^ip [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$|ip ${OK_IP}|g" /opt/openkore/tables/servers.txt
sed -i "s|^addTableFolders.*|addTableFolders ${OK_ADDTABLEFOLDERS}|g" /opt/openkore/tables/servers.txt
sed -i "s|^master_version.*|master_version ${OK_MASTER_VERSION}|g" /opt/openkore/tables/servers.txt
sed -i "s|^version.*|version ${OK_VERSION}|g" /opt/openkore/tables/servers.txt
sed -i "s|^charBlockSize.*|charBlockSize ${OK_CHARBLOCKSIZE}|g" /opt/openkore/tables/servers.txt
sed -i "s|^serverType.*|serverType ${OK_SERVER_TYPE}|g" /opt/openkore/tables/servers.txt

sed -i "s|^bus 0|bus 1|g" /opt/openkore/control/sys.txt

echo "moc_fild20 10000" >> /opt/openkore/control/routeweights.txt
echo "moc_fild22 10000" >> /opt/openkore/control/routeweights.txt
echo "moc_fild21 10000" >> /opt/openkore/control/routeweights.txt

if ! [ -z "${OK_FOLLOW_USERNAME1}" ]; then
    printf "Setting follow target to %s\n" "${OK_FOLLOW_USERNAME1}"
    sed -i "s|^followTarget.*|followTarget ${OK_FOLLOW_USERNAME1}|g" /opt/openkore/control/config.txt
fi

printf "\nOpenKore configuration complete, launching instance\n\n"
printf "===================================================\n\n"

exec "$@"
