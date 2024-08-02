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
if [ -z "${OK_CHAR}" ]; then OK_CHAR=0; fi

# Define the probabilities for each option
FOLLOW_PROB1=1  # 100% chance of following OK_FOLLOW_USERNAME1
FOLLOW_PROB2=0  # 0% chance of following OK_FOLLOW_USERNAME2
NO_FOLLOW_PROB=0  # 0% chance of not following anyone

# Generate a random number between 0 and 1
RANDOM_NUM=$(awk 'BEGIN{srand(); print rand()}')

if [ "${OK_KILLSTEAL}" = "1" ]; then 
    sed -i "1507s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1534s|return 0|return 1|" /opt/openkore/src/Misc.pm
    sed -i "1571s|return !objectIsMovingTowardsPlayer(\$monster);|return 1;|" /opt/openkore/src/Misc.pm
    sed -i "1583s|return 0|return 1|" /opt/openkore/src/Misc.pm
fi

if [ -z "${OK_USERNAMEMAXSUFFIX}" ]; then
    sed -i "s|^username.*|username ${OK_USERNAME}|g" /opt/openkore/control/config.txt
else
    if [ -z "${MYSQL_HOST}" ]; then echo "Missing MYSQL_HOST environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_DB}" ]; then echo "Missing MYSQL_DB environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_USER}" ]; then echo "Missing MYSQL_USER environment variable. Unable to continue."; exit 1; fi
    if [ -z "${MYSQL_PWD}" ]; then echo "Missing MYSQL_PWD environment variable. Unable to continue."; exit 1; fi
    for i in `seq 0 ${OK_USERNAMEMAXSUFFIX}`;
    do
        USERNAME=${OK_USERNAME}${i}
        MYSQL_ACCOUNT_ID_QUERY="SELECT \`account_id\` FROM \`login\` WHERE userid='${USERNAME}';"
        ACCOUNT_ID=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_ACCOUNT_ID_QUERY}");
        MYSQL_CHAR_NAME_QUERY="SELECT \`name\` FROM \`char\` WHERE account_id='${ACCOUNT_ID}' AND char_num='${OK_CHAR}';"
        CHAR_NAME=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_CHAR_NAME_QUERY}");
        MYSQL_QUERY="SELECT \`online\` FROM \`char\` WHERE account_id='${ACCOUNT_ID}' AND char_num='${OK_CHAR}';"
        CHAR_IS_ONLINE=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}");

        printf "Username %s (%s) online status: %s\n" "$USERNAME" "$CHAR_NAME" "$CHAR_IS_ONLINE"

        if [ "${CHAR_IS_ONLINE}" == "0" ]; then
            MYSQL_QUERY="UPDATE \`char\` SET \`online\`=1 WHERE name='${USERNAME}'"
            mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "${MYSQL_QUERY}"
            CLASS=$(mysql -u${MYSQL_USER} -p${MYSQL_PWD} -h ${MYSQL_HOST} -D ${MYSQL_DB} -ss -e "SELECT class FROM \`char\` WHERE char_num='${OK_CHAR}' AND account_id='${ACCOUNT_ID}';")

            printf "Selected username %s (%s) (%s)\n" "${USERNAME}" "${CHAR_NAME}" "${CLASS}"
            case ${CLASS} in
                4) # ACOLYTE
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/acolyte.txt /opt/openkore/control/config.txt
                    ;;
                8) # PRIEST
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/priest.txt /opt/openkore/control/config.txt
                    ;;
                15) # MONK
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/monk.txt /opt/openkore/control/config.txt
                    ;;
                5) # Merchant
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/merchant.txt /opt/openkore/control/config.txt
                    ;;
                10) # Blacksmith
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/blacksmith.txt /opt/openkore/control/config.txt
                    ;;
                2) # MAGE
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/mage.txt /opt/openkore/control/config.txt
                    ;;
                9) # WIZARD
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/wizard.txt /opt/openkore/control/config.txt
                    ;;
                16) # SAGE
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/sage.txt /opt/openkore/control/config.txt
                    ;;
                3) # Archer
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/archer.txt /opt/openkore/control/config.txt
                    ;;
                11) # Hunter 
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/hunter.txt /opt/openkore/control/config.txt
                    ;;
                1) # SWORDMAN
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/swordman.txt /opt/openkore/control/config.txt
                    ;;
                7) # KNIGHT
                    mv /opt/openkore/control/config.txt /opt/openkore/control/config.txt.bak
                    cp /opt/openkore/control/class/knight.txt /opt/openkore/control/config.txt
                    ;;
            esac
            sed -i "s|^username.*|username ${USERNAME}|g" /opt/openkore/control/config.txt
            
            # Check the random number against the probabilities
            if ( $(echo "$RANDOM_NUM < $FOLLOW_PROB1" | bc -l) ); then
                if ! [ -z "${OK_FOLLOW_USERNAME1}" ]; then
                    sed -i "s|^followTarget.*|followTarget ${OK_FOLLOW_USERNAME1}|g" /opt/openkore/control/config.txt
                    #sed -i "s|^attackAuto 2$|attackAuto 1|g" /opt/openkore/control/config.txt
                fi
            elif (( $(echo "$RANDOM_NUM < $FOLLOW_PROB1 + $FOLLOW_PROB2" | bc -l) )); then
                if ! [ -z "${OK_FOLLOW_USERNAME2}" ]; then
                    sed -i "s|^followTarget.*|followTarget ${OK_FOLLOW_USERNAME2}|g" /opt/openkore/control/config.txt
                    #sed -i "s|^attackAuto 2$|attackAuto 1|g" /opt/openkore/control/config.txt
                fi
            else
                # Do not follow anyone
                sed -i "s|^followTarget.*|followTarget |g" /opt/openkore/control/config.txt
                sed -i "s|^attackAuto 1$|attackAuto 2|g" /opt/openkore/control/config.txt
            fi

            break
        fi
    done
fi
sed -i "s|^master$|master ${OK_SERVER}|g" /opt/openkore/control/config.txt
sed -i "s|^server.*|server 0|g" /opt/openkore/control/config.txt
sed -i "s|^password$|password ${OK_PWD}|g" /opt/openkore/control/config.txt
sed -i "s|^char$|char ${OK_CHAR}|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponse 0$|autoResponse 1|g" /opt/openkore/control/config.txt
sed -i "s|^autoResponseOnHeal 0$|autoResponseOnHeal 1|g" /opt/openkore/control/config.txt
sed -i "s|^route_randomWalk_inTown 0$|route_randomWalk_inTown 1|g" /opt/openkore/control/config.txt
sed -i "s|^partyAuto 1$|partyAuto 2|g" /opt/openkore/control/config.txt
sed -i "s|^follow 0$|follow 1|g" /opt/openkore/control/config.txt
sed -i "s|^followSitAuto 0$|followSitAuto 1|g" /opt/openkore/control/config.txt
sed -i "s|^attackAuto_inLockOnly 1$|attackAuto_inLockOnly 0|g" /opt/openkore/control/config.txt

sed -i "s|^lockMap$|lockMap gef_fild07|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_x$|lockMap_x 218|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_y$|lockMap_y 185|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_randX$|lockMap_randX 115|g" /opt/openkore/control/config.txt
sed -i "s|^lockMap_randY$|lockMap_randY 20|g" /opt/openkore/control/config.txt

sed -i "s|^ip [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$|ip ${OK_IP}|g" /opt/openkore/tables/servers.txt

exec "$@"
