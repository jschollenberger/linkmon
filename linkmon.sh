#!/bin/bash





#readme


# Tuneables for linkmon

# Seconds to sleep between polling asterisk (1 minute default, other values untested)
SLEEP_TIME=60

# Total inactivity allowed in minutes (3 minute default)
INACTIVITY_ALLOWANCE=3

# Path to your asterisk binary
ASTERISK=/usr/sbin/asterisk

# Path to your allstar env file
ALLSTARENV=/usr/local/etc/allstar.env

# Path to astdb.txt
ASTDB=/var/log/asterisk/astdb.txt

# Play a global message before connecting and after disconnecting with information about the link status (default 1)
ANNOUNCE_LINK=1

# Configuration ends here
# ============================================================================================================ #

echo

# Check if we're already running

if pidof -o %PPID -x "linkmon.sh">/dev/null; then
    echo "Linkmon already running. I can only run one instance at a time. Exiting..."
    exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo_date "ctrl-c pressed. disconnecting link and exiting..."
    link_disconnect
    exit 1
}

# Set $TEMPORARY_LINK and $LINK_TIME to provided arguments

if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: linkmon.sh <node ID to connect to> <link time in minutes> <optional local node ID>"
    echo "For example, to connect to node 53209 for 60 minutes you would run: linkmon.sh 53209 60"
    echo "Please specify link to connect to and for how long. Exiting..."
    exit 1
else
    # Remote node ID
    TEMPORARY_LINK=$1
    # Time to keep the link connected (minutes)
    LINK_TIME=$2
fi

# If it's not in the parameter, get local node number from the allstar.env

if [ -z "$3" ]; then
    if [ -f $ALLSTARENV ] ; then
        source $ALLSTARENV
        LOCALNODE=$NODE1
    else
        echo "No local node ID provided and missing Allstar environment file ($ALLSTARENV). Exiting..."
        exit 1
    fi
else
    LOCALNODE=$3
fi

# Get info about link argument from the astdb

if [ -f $ASTDB ] ; then
    TEMPORARY_LINK_INFO="- `grep -w $TEMPORARY_LINK $ASTDB | cut -d\| -f 2-4`"
fi

# function to disconnect outbound links
disconnect_outbound_links () {
    local OUTBOUNDLINKS=`$ASTERISK -rx "rpt lstats $NODE1" | grep "OUT" | awk {'print $1'}`
    if [[ -z "$OUTBOUNDLINKS" ]] ; then
        echo "... None found."
    else
        echo ": $OUTBOUNDLINKS"
        for i in $OUTBOUNDLINKS
        do
            $ASTERISK -rx "rpt cmd $NODE1 ilink 11 $i" &> /dev/null
        done
    fi
}

# Function to check if the specified link is connected
link_status () {
    local LSTATS=`$ASTERISK -rx "rpt lstats $LOCALNODE" | grep $TEMPORARY_LINK`
    if [[ -z "$LSTATS" ]] ; then
        echo "Warning: Link $TEMPORARY_LINK is not connected to $LOCALNODE."
    else
        echo $LSTATS
    fi
}

# Function to get total TX time since initilization in seconds
get_txtime_seconds () {
    TXTIME=`$ASTERISK -rx "rpt stats $LOCALNODE" | grep -i 'TX time since system initialization'| awk '{print $(NF)}'`
    TXINT=${TXTIME%.*}
    TXSECONDS=`echo "$TXINT" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'`
    echo $TXSECONDS
}

seconds_to_timestamp () {
    printf '%02dh:%02dm:%02ds\n' $(($1/3600)) $(($1%3600/60)) $(($1%60))
}

# Function to disconnect from a link
link_disconnect () {
    $ASTERISK -rx "rpt cmd $LOCALNODE ilink 11 $TEMPORARY_LINK" &> /dev/null
    sleep 1 & wait $!
    announce_link disconnect
}

# Function to connect to a link
link_connect() {
    announce_link connect
    sleep 5 & wait $!
    $ASTERISK -rx "rpt cmd $LOCALNODE ilink 13 $TEMPORARY_LINK" &> /dev/null
}


# Function to announce link connect and disconnect messages
announce_link() {
    if [[ "$ANNOUNCE_LINK" -eq 1 ]] ; then
        ACTION=$1
        AUDIO_FILE="/etc/asterisk/local/$TEMPORARY_LINK-$ACTION"

        if ! compgen -G "${AUDIO_FILE}*" > /dev/null ; then
            AUDIO_FILE="/etc/asterisk/local/node-$ACTION"
        fi

        $ASTERISK -rx "rpt localplay $NODE1 $AUDIO_FILE" &> /dev/null
    fi
}

# Get tx time from asterisk and write it to both variables
LASTTXTIME=$(get_txtime_seconds)
CURRENTTXTIME=$(get_txtime_seconds)
LINK_TIMER_START=`date +%s`
INACTIVE_MINUTES=0

# Function to echo to console with the datetime prepended
echo_date () {
    echo "[$(date '+%m/%d/%Y %H:%M:%S')] "$1""
}

# Function to convert seconds to minutes
seconds_to_minutes() {
    echo `echo "$1 / 60" | bc`
}


echo_date "Monitoring temporary transceive link: $TEMPORARY_LINK $TEMPORARY_LINK_INFO"
echo_date "The link will automatically disconnect after $LINK_TIME minutes at `date -d \"$LINK_TIME minutes\" +'%H:%M'` OR after $INACTIVITY_ALLOWANCE cumulative minutes of inactivity."
echo
echo_date "Disconnecting existing outbound links$(disconnect_outbound_links)"
echo_date "Establishing connection to: $TEMPORARY_LINK..."
link_connect
sleep 1 & wait $!
echo_date "Link Information: $(link_status)"
echo
echo_date "Current TX time for Node $LOCALNODE: $(seconds_to_timestamp $CURRENTTXTIME)"
echo_date "Sleeping $SLEEP_TIME seconds..."

sleep $SLEEP_TIME & wait $!

while [[ "$CURRENTTXTIME" -ge "$LASTTXTIME" || "$INACTIVE_MINUTES" -lt "$INACTIVITY_ALLOWANCE" ]]
do
    CURRENTTXTIME=$(get_txtime_seconds)

    LINK_TIMER_NOW=`date +%s`
    LINK_TIMER_SECONDS=$((LINK_TIMER_NOW-LINK_TIMER_START))
    LINK_TIMER_MINUTES=$(seconds_to_minutes $LINK_TIMER_SECONDS)

    if [ "$LINK_TIMER_MINUTES" -ge "$LINK_TIME" ]; then
        echo_date "Link Timer exceeded: $LINK_TIMER_MINUTES of $LINK_TIME minutes. Disconnecting link $TEMPORARY_LINK."
        link_disconnect
        break
    fi

    if [ "$CURRENTTXTIME" -gt "$LASTTXTIME" ]; then
        echo_date "TX time increasing: $(seconds_to_timestamp CURRENTTXTIME) > $(seconds_to_timestamp $LASTTXTIME). Link Timer: $LINK_TIMER_MINUTES of $LINK_TIME minutes. Sleeping $SLEEP_TIME seconds..."
        LASTTXTIME=$CURRENTTXTIME
        CURRENTTXTIME=$(get_txtime_seconds)
        sleep $SLEEP_TIME & wait $!
    elif [ "$CURRENTTXTIME" -eq "$LASTTXTIME" ]; then
        ((INACTIVE_MINUTES++))
        if [ "$INACTIVE_MINUTES" -lt "$INACTIVITY_ALLOWANCE" ]; then
            echo_date "TX time not increasing: $(seconds_to_timestamp $CURRENTTXTIME) = $(seconds_to_timestamp $LASTTXTIME). $INACTIVE_MINUTES of $INACTIVITY_ALLOWANCE minute inactivity allowance."
            sleep $SLEEP_TIME & wait $!
        else
            echo_date "TX time not increasing: $(seconds_to_timestamp $CURRENTTXTIME) = $(seconds_to_timestamp $LASTTXTIME). Disconnecting link $TEMPORARY_LINK."
            link_disconnect
            break
        fi
    fi
done

if [ "$CURRENTTXTIME" -lt "$LASTTXTIME" ]; then
    echo_date "TX time decreased: $(seconds_to_timestamp $CURRENTTXTIME) < $(seconds_to_timestamp $LASTTXTIME). This shouldn't happen. Disconnecting link $TEMPORARY_LINK and bailing..."
    link_disconnect
    exit
fi

echo_date "Linkmon shutting down..."
