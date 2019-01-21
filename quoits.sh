#!/bin/sh
set -e
set -u
#set -x

umask 0022


# find the full path of our executable self
if echo $0 | grep -q '^/'; then
    EXEC=$0
else
    EXEC=$(pwd)/$0
fi

VERSION=$(stat -c '%z' $EXEC | cut -d. -f1 )

QHOME=$(mktemp -d /tmp/quoits.XXXXXX)
cd ${QHOME}

VAULT=/vault/quoits
mkdir -p $VAULT
mkdir -p $VAULT/macros

ZIPCODE=07066 

bigboard=$(which bigboard) || true
weather=$(which weather) || true

macro=""

macrocleanse () {
    # given the user-input macro name
    # strip everything that isn't letter, nubmer, underscore, or dash
    # and print the full path of the file
    echo $VAULT/macros/$(echo $* | sed 's/[^-a-zA-Z0-9_]//g')
}


banner () {
    printf ">>>      QUOITS Unix-Operated Interactive Teletype System      <<<\n"
    printf ">>>      %48s      <<<\n" "v.$VERSION"
    echo
}

version () {
    echo "QUOITS version $VERSION"
}

quoitscommand () {
    set $1

    case "$1" in
    "?"|h|he|hel|help|hell|hello)
        version
        test -n "$bigboard" && echo '  ( bb | bigboard )'
        echo '  brightness 0-7'
        echo '  date'
        echo '  echo MESSAGE'
        echo '  help | ?'
        echo '  intro'
        echo '  fs ( up | down ) FILESYSTEM [ mem ]'
        echo '  macro ( abort | ls | stop )'
        echo '  macro ( cat | play | record ) MACRO'
	    echo '   # .MACRO is short for `macro play MACRO` #'
        echo '  net ls'
        echo '  net ( up | down | stat ) DEVICE'
        echo '  poweroff'
        echo '  reboot'
        echo '  spin[down] [ build | vault ]'
        echo '  sv ( ntpd | tor ) ( up | down )'
        echo '  ( tz | timezone ) [--show]'
        echo '  user ls'
        echo '  user ( up | down | load | save | shell | stat ) USERNAME'
        test -n "$weather" && echo '  weather'
        echo '  zip [ ZIPCODE ] '
        echo '(unique substrings also mostly work)'
        ;;
    
    .*)
        quoitscommand "macro play $(echo $1 | sed 's/.//')"
        ;;

    bb|bi|big|bigb|bigboard)
        test -z "$bigboard" && echo "! not available" && continue
        if ! bigboard; then
	        echo "bigboard crashed"
        else
            reset
        fi
        ;;

    br|bri|bright|brite|brightness|briteness)
        if [ $# -lt 2 ]; then
	    cat /sys/class/backlight/acpi_video0/brightness
            return 0
        fi
        if echo "$2" | grep -q '^[0-7]$'; then 
            echo "$2" > /sys/class/backlight/acpi_video0/brightness
        else
            echo "value out of range(0-7): '$2'"
        fi
        ;;

    d|da|dat|date)
	date
        ;;

    echo)
        shift
        echo "$*"
        ;;

    f|fs)
        shift
        optmount $* || true
        ;;

    i|in|int|intr|intro)
	if [ -f /usr/share/quoits.intro ]; then
	        less /usr/share/quoits.intro
	else
		echo "! no intro file found"  
		continue
	fi
        ;;

    m|ma|mac|macr|macro)
        shift
        if [ $# -lt 1 ]; then
            echo "! macro ( abort | cat | list | play | record | stop)"
            return
        fi
        case $1 in
        a|ab|abo|abor|abort)
            test -n "$macro" && rm -f $macro
            macro=""
            ;;
        c|ca|cat)
            if [ $# -lt 2 ]; then
                echo "! cat MACRONAME"
                return
            fi
            macfile=$(macrocleanse $2)
            if [ ! -f $macfile ]; then
                echo "! macro $2 not found"
                return
            fi
            grep -v '^#' $macfile
            ;;
        l|ls|list)
            ls $VAULT/macros
            ;;
        p|pl|play)
            if [ $# -lt 2 ]; then
                echo "! play MACRONAME"
                return
            fi
            macfile=$(macrocleanse $2)
            if [ ! -f $macfile ]; then
                echo "! macro $2 not found"
                return
            fi
            while read REPLY; do
                if echo $REPLY | grep -q '^#.*'; then
                    continue
                fi
                quoitscommand "$REPLY"
            done < $macfile
            ;;
        r|re|rec|record)
            if [ -n "$macro" ]; then
                echo "! forbidden. closing existing macro $(basename $macro)"
                quoitscommand macro abort
                return 0
            fi
            macro=$(macrocleanse $2)
            if [ -f $macro ] ; then
                echo "! macro $macro exists"
                quoitscommand macro abort
            fi
            echo "# QMR begin $(date)" > $macro
            ;;
        s|st|sto|stop)
            if [ -z "$macro" ]; then
                "! no macro recording"
            else
                echo "# QMR end $(date)" >> $macro
            fi
            macro=""
            ;;
        esac
        ;;

    n|ne|net)
        shift
        netutil $* || true
        ;;

    p|po|pow|power|poweroff)
        init 0
        ;;

    q|qu|qui|quo|quit|quoi|quoit|quoits)
        cd /
        rm -rf $QHOME
        exit 0
        ;;

    r|re|reb|reboot)
        init 6
        ;;

    sp|spi|spin|spindown)
        shift
        targets=""
        if [ $# -ge 1 ]; then
            test $1 = "build" && targets="build"
            test $1 = "vault" && targets="vault"
        else
            targets="build vault"
        fi
        test -z "$targets" && echo "! Invalid target: '$*'"
        for t in $targets; do
            df /$t | grep -q "rootfs" && continue   # not mounted
            umount /$t 2>/dev/null || echo "$t is busy"
        done
        ;;
    sv|svc)
        shift
        test $# -ge 2 || svtool || true
        case $2 in
        ntpd|tor)
            svtool $* || true
            ;;
        *)
           echo "! service not found: $2"
        esac
	;;

    t|tz|timezone)
        shift
        tz $* || true
        ;;

    u|us|use|user)
        shift
        usertool $* || true
        ;;
    v|ve|ver|vers|version)
        version
        ;;
    w|we|wea|weather)
        test -z "$weather" && echo "! not available" && continue
        if [ $# -ge 1 ]; then
            weather $(echo $* | sed 's/[^0-9]//g')
        else
            weather $ZIPCODE || true
        fi
        ;;
    z|zi|zip)
        test $# -eq 1  && echo "ZIP code is $ZIPCODE" && continue
        ZIPCODE=$(echo $* | sed 's/[^0-9]//g')
        export ZIPCODE
        ;;

    *)
        echo "?"
        ;;
    esac
}

## main loop

banner

while true; do
    echo -n "quoits> "
    read
    if [ -z "$REPLY" ]; then
        continue
    fi
    
    test -n "$macro" && inmacro=true || inmacro=false

    quoitscommand "$REPLY"

    if [ -n "$macro" ] && $inmacro; then
        # don't save record/save commands
        echo "$REPLY" >> $macro
    fi
done


