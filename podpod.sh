#!/bin/bash

# Podpod by Clemens Meissner <clemens.meissner[at]posteo.de>
# Copyright 2017

usage()
{
    echo ""
    echo $0 podpod.conf
    echo "  --help                                   Display this help message and exit"
    echo "  --hook [start|cast|file|end] hook.sh     Set up a hook script"
    echo ""
    echo "  Hooks and their execution times:"
    echo "    start     after successful startup, before first podcast is checked"
    echo "    cast      after every successfull complete podcast check"
    echo "                parameter: directory of successfully retrieved podcast"
    echo "    file      after every successfully downloaded file"
    echo "                parameter: downloaded file"
    echo "    end       after all podcasts are finished"
    echo ""
}

# outputs a composed relative path of the first two arguments if the second one
# is not an absolute path i.e. $1/$2 if $2 is not absolute
function relIfNotAbsolute() {
    if [[ $2 == /* ]]; then
        echo $2
    else
        echo $1/$2
    fi
}

# Reads a path variable from the $RSS_FILE and makes it relative to the config
# file if necesssary. Also checks for the loaded value to be readable
# $1 : Name of the variable that should be read
# $2 : Either FILE or DIR to indicate what should be tested
function readVariablePath() {
    declare "$1"=$( relIfNotAbsolute $CONFIG_DIR ${!1} )
    if [[ $2 == "FILE_CREATE" ]]; then
        touch ${!1}
        if [[ $? -ne 0 ]]; then
            echo "Error creating logfile. Disabled logging."
            declare "$1"=""
        fi
    elif [[ $2 == "FILE" && ! -f ${!1} ]]; then
        echo "$1 '${!1}' could not be read" >> /dev/stderr
        echo "Before exit" >> /dev/stderr
        exit 7
    elif [[ $2 == "DIR" && ! -d ${!1} ]]; then
        mkdir -p ${!1}
        if [[ ! -d ${!1} ]]; then
            echo "$1 '${!1}' could not be read" >> /dev/stderr
        fi
    fi
    echo ${!1}
}

function log() {
    # If the second parameter is set to nonzero, only log to file
    if [[ -z $2 || $2 -eq 0 ]]; then
        echo "$1"
    fi
    # If present, log to file
    if [[ -n $LOGGING_FILE ]]; then
        echo "$1" >> $LOGGING_FILE
    fi
}

function die() {
    if [[ -n $2 ]]; then
        echo $2
        usage
    fi
    exit $1
}

### MAIN SCRIPT ###

echo ""

if [[ -n $( echo $@ | grep -- "--help" ) ]]
then
    usage
    exit 0
fi

CONFIG_FILE=""
HOOK_START=""
HOOK_CAST=""
HOOK_FILE=""
HOOK_END=""

while :
do
    # If the first one is empty, we've shifted through every parameter
    if [[ -z $1 ]]; then break; fi

    # Check if this parameter is a long option (needed for future work)
    # Set to 1 if the first options (--... ) is used
    LONGOPT=0
    if [[ -n $(echo $1 | egrep -- '--.+') ]]; then
        LONGOPT=1
    fi

    # The first parameter which is not preceeded by "--" is the config file.
    if [[ $LONGOPT -eq 0 ]]; then
        if [[ ! -f $1 ]]; then
            die 6 "Config file '$1' not found"
        fi
        CONFIG_FILE=$1
    elif [[ $1 == "--hook" ]]; then
        if [[ -z $2 || -z $3 ]]; then
            die 1 "'--hook' requires both a hook specifier and a script"
        fi
        if [[ $2 != "start" && $2 != "cast" && $2 != "file" && $2 != "end" ]]; then
            die 2 "Cannot specify a hook script for action '$2'"
        fi
        if [[ ! -x $3 ]]; then
            die 3 "'$3' is not a usable executable for hook '$2'"
        fi
        # $1 is hook, $2 is the specifier, $3 is the hook script
        SPECIFIER=$( echo $2 | tr [:lower:] [:upper:] )
        declare "HOOK_${SPECIFIER}"=$3

        ## Assure we shift through EVERYTHING belonging to the hooks
        shift; shift;
    fi

    shift
done

if [[ -z $CONFIG_FILE ]]; then
    die 4 "Please specify a config file."
fi
CONFIG_DIR=$(dirname $CONFIG_FILE)

### CHECK CONFIGURATION ###

# Source the config file and read the value, if some are not given, set defaults
. $CONFIG_FILE

if [[ -n $LOGGING_FILE ]]; then
    LOGGING_FILE=$(readVariablePath LOGGING_FILE FILE_CREATE)
fi

if [[ -z $RSS_FILE ]]; then
    log "ERROR: 'RSS_FILE' not set in config file ($(CONFIG_FILE))"
    exit 5
fi
RSS_FILE=$(readVariablePath RSS_FILE FILE)


if [[ -z $PODCASTS_DIR ]]; then
    log "No podcast directory set, using CONFIG_DIR ${CONFIG_DIR}"
    PODCASTS_DIR=$(readlink -f $CONFIG_DIR )
fi
PODCASTS_DIR=$(readVariablePath PODCASTS_DIR DIR)

# Log the startup
log ""  0
log ""  0
log "Starting PodPod at $(date) with"   0
log "   RSS_FILE     = $RSS_FILE"       1
log "   PODCASTS_DIR = $PODCASTS_DIR"   1
log "   CONFIG_FILE  = $CONFIG_FILE"    1
log "   LOGGING_FILE = $LOGGING_FILE"   1
log "   HOOK_START   = $HOOK_START"     1
log "   HOOK_CAST    = $HOOK_CAST"      1
log "   HOOK_FILE = $HOOK_FILE"         1
log "   HOOK_END = $HOOK_END"           1


## Execute the start hook script as all config tests are done.
if [[ -x $HOOK_START ]]; then
    bash $HOOK_START
fi

# Iterate over every entry of the RSS file.
while read LINE; do

    # Ignore blank lines and lines starting with '#'
    if [[ -z "$LINE" || -n $( echo "$LINE" | egrep '^\s*$') || -n $( echo "$LINE" | egrep '^#.*$' ) ]]; then
        continue
    fi
    NAME=$( echo $LINE | cut -d' ' -f 1 )
    URL=$(  echo $LINE | cut -d' ' -f 2 )
    MODE=$( echo $LINE | cut -d' ' -f 3 )

    ## Check the modes.
    MAX_DLDS="-1"
    case "$MODE" in
        "sim")
            MAX_DLDS=-1
            ;;
        "all")
            MAX_DLDS=-1
            ;;
        "latest")
            MAX_DLDS=1
            ;;
        *)
            if [[ $(echo "$MODE"+0 | bc) -le 0 ]]; then
                log "Invalid mode '$MODE' found. Select from sim, all, latest or a non-negative intege"
                log "Ignoring entry"
                continue;
            else
                MAX_DLDS=$MODE
            fi
            ;;
    esac

    # Hidden feature, allow sim and a limited number of downloads
    if [[ $MODE == "sim" ]]; then
        SIM_MAX=$( echo $LINE | cut -d' ' -f 4 )
        if [[ $SIM_MAX -gt 0 ]]; then
            MAX_DLDS=$SIM_MAX
        fi
    fi

    CAST_DIR=$PODCASTS_DIR/$NAME
    CAST_LOGFILE=$CAST_DIR/podpod.log
    CAST_XMLFILE=$CAST_DIR/latest.xml

    # Prepare the directory for this podcast
    mkdir -p $CAST_DIR
    touch $CAST_LOGFILE
    CAST_OLDLOG=$( cat $CAST_LOGFILE )

    # Aqcuire podcast xml file
    wget -q $URL -O $CAST_XMLFILE
    retVal=$?
    if [[ $retVal -ne 0 ]]; then
        if [[ $retVal -eq 4 ]]; then
            log "Network error. Abort."
            exit 3;
        else
            log "Error acquiring XML file. Skipping podcast"
            continue;
        fi
    fi

    XML=$( cat $CAST_XMLFILE )
    CHANNEL=$( echo "$XML" | xmllint -xpath "/rss/channel" - )
    TITLE=$( echo "$CHANNEL" | xmllint -xpath "/channel/title/text()" - 2> /dev/null )
    log ""
    log "Checking podcast '$TITLE'"

    ITEM_LAST_DATE=$( echo "$CHANNEL" | xmllint -xpath "/channel/item[last()]/pubDate/text()" - 2>/dev/null )

    # Iterate over all entrys present and download if needed
    i=0
    while [[ $MAX_DLDS -eq -1 || $i -lt $MAX_DLDS ]]
    do
        # Idexing for xmllint (i.e. XPath) starts with 1
        i=$(( $i + 1 ))

        ITEM_I=$( echo "$CHANNEL" | xmllint -xpath "/channel/item[$i]" - 2> /dev/null )
        ITEM_I_DATE=$( echo "$ITEM_I" | xmllint -xpath "/item[1]/pubDate/text()" - 2> /dev/null )
        ITEM_I_TITLE=$( echo "$ITEM_I" | xmllint -xpath "/item[1]/title/text()" - 2> /dev/null )
        ITEM_I_URL=$( echo "$ITEM_I" | xmllint -xpath "string(/item[1]/enclosure/@url)" - 2> /dev/null )

        ITEM_I_UTC=$( date --date="$ITEM_I_DATE" --utc --iso-8601=seconds )
        ITEM_I_LOGENTRY="$ITEM_I_UTC:$ITEM_I_URL"


        log "  Ep. $i:'$ITEM_I_TITLE'"
        # Check if the current element has already been logged (and thus downloaded or faked/simulated)
        if [[ -n $(echo $CAST_OLDLOG | grep "$ITEM_I_LOGENTRY") ]]; then
            log "    ... already present"
            continue
        fi

        # Compose a filename for the file that (may) will be downloaded
        DATESTRING=$(date  --date="$ITEM_I_DATE" "+$DATE_FORMAT") # This also works if the format string is empty
        DL_FILENAME=$(basename $ITEM_I_URL)
        if [[ -n $DATESTRING ]]; then
            DL_FILENAME="$DATESTRING-$DL_FILENAME"
        fi

        # Only download if not simulate
        if [[ "$MODE" != "sim" ]]; then
            wget $ITEM_I_URL -O "$CAST_DIR/$DL_FILENAME"
#            touch ${CAST_DIR}/${DL_FILENAME}
            if [[ $? -eq 0 ]]; then
                log "    ... acquired"
            else
                log "    ... Error acquiring file. Skipping remaining files."
                break
            fi
        fi

        if [[ -x $HOOK_FILE ]]; then
            bash $HOOK_FILE ${DL_FILENAME}
        fi
        echo "$ITEM_I_LOGENTRY" >> $CAST_LOGFILE


        # Continue at most as long a we haven't reached the last item in the list of podcast items
        if [[ $ITEM_I_DATE == $ITEM_LAST_DATE ]]; then
            break
        fi

    done # Iteration over every item for one podcast

    if [[ -x $HOOK_CAST ]]; then
        bash $HOOK_CAST ${CAST_DIR}
    fi

done < $RSS_FILE # Iteration over every RSSFILE entry

if [[ -x $HOOK_END ]]; then
    bash $HOOK_END
fi
