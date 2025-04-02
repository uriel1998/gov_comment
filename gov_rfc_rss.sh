#!/bin/bash

##############################################################################
#
#  To scrape for new requests for comment from the US government, obtain the 
#  full text, and present it as an RSS feed.
#  Requires xmlstarlet as well as wget, sed, awk, grep, etc.
#  (c) Steven Saus 2025
#  Licensed under the MIT license
#
##############################################################################


###############################################################################
# Establishing XDG directories, or creating them if needed.
# standardized binaries that should be on $PATH
# Likewise with initial INI files
############################################################################### 
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
export INSTALL_DIR="$(dirname "$(readlink -f "$0")")"
LOUD=1
wget_bin=$(which wget)
TEMPDIR=$(mktemp -d)
export self_link=https://example.com/rss.xml
link=""
description=""
title=""

if [ -z "${XDG_DATA_HOME}" ];then
    export XDG_DATA_HOME="${HOME}/.local/share"
    export XDG_CONFIG_HOME="${HOME}/.config"
fi

if [ ! -d "${XDG_DATA_HOME}/gov_rfc_rss" ];then
    mkdir -p "${XDG_DATA_HOME}/gov_rfc_rss"
    
fi

# Now we can set these
export DATADIR="${XDG_DATA_HOME}/gov_rfc_rss"
ArchiveFile="${DATADIR}/retrieved_urls.txt"
export RSSSavePath="${DATADIR}/gov_rfc_rss.xml"

if [ ! -d "${XDG_CONFIG_HOME}" ];then
    echo "Your XDG_CONFIG_HOME variable is not properly set and does not exist."
    exit 99
fi

# This may work with firefox/mercury/etc, just haven't tried.

chromium_bin=$(which chromium)
if [ ! -f "${chromium_bin}" ];then
    chromium_bin=$(which chromium-browser)
    if [ ! -f "${chromium_bin}" ];then
        chromium_bin=$(which google-chrome)
        if [ ! -f "${chromium_bin}" ];then
            loud "## ERROR: I can't find chromium, try editing the script."
            exit 99
        fi
    fi
fi

###############################################################################
# Functions
###############################################################################

#https://stackoverflow.com/questions/12827343/linux-send-stdout-of-command-to-an-rss-feed    
function rss_gen_send {
    if [ ! -f "${RSSSavePath}" ];then
        loud "[info] Starting XML file"
        printf '<?xml version="1.0" encoding="utf-8"?>\n' > "${RSSSavePath}"
        printf '<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">\n' >> "${RSSSavePath}"
        printf '  <channel>\n' >> "${RSSSavePath}"
        printf '    <title>My RSS Feed</title>\n' >> "${RSSSavePath}"
        printf '    <description>This is my RSS Feed</description>\n' >> "${RSSSavePath}"
        printf '    <link rel="self" href="%s" />\n' "${self_link}" >> "${RSSSavePath}"
        printf '  </channel>\n' >> "${RSSSavePath}"
        printf '</rss>\n' >> "${RSSSavePath}"    

    fi
    TITLE="${title}"
    LINK=$(printf "href=\"%s\"" "${link}")
    DATE="`date`"
    DESC=$(printf "\n%s\n" "${description}")
    GUID="${link}" 
    loud "[info] Adding entry to RSS feed"
    xmlstarlet ed -L   -a "//channel" -t elem -n item -v ""  \
         -s "//item[1]" -t elem -n title -v "$TITLE" \
         -s "//item[1]" -t elem -n link -v "$LINK" \
         -s "//item[1]" -t elem -n pubDate -v "$DATE" \
         -s "//item[1]" -t elem -n description -v "$DESC" \
         -s "//item[1]" -t elem -n guid -v "$GUID" \
         -d "//item[position()>10]"  "${RSSSavePath}" ; 
}


function loud() {
##############################################################################
# loud outputs on stderr 
##############################################################################    
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
    fi
}


###############################################################################
# Script Enters Here
###############################################################################


#Use chromium to get web page
loud "# Grabbing search page data"
${chromium_bin} --headless --dump-dom --virtual-time-budget=10000 --timeout=10000 "https://www.govinfo.gov/app/search/%7B%22query%22%3A%22%5C%22request%20for%20comment%5C%22%22%2C%22offset%22%3A0%2C%22sortBy%22%3A%222%22%2C%22pageSize%22%3A10%7D" > "${TEMPDIR}/dom.html"

#Use sed to extract articles
loud "# Extracting articles"
cat "${TEMPDIR}/dom.html" | sed 's/>/>\n/g' | sed -n '/<ol/,/<\/ol>/p' | sed -n '/<article/,/<\/article>/p' > "${TEMPDIR}/articles.html"

#Use awk to extract urls of text versions
loud "# Extracting urls of actual articles"
cat "${TEMPDIR}/articles.html" | grep -e "/html/" | awk -F '"' '{print "https://www.govinfo.gov" $4}' > "${TEMPDIR}/urls.txt"


cat "${TEMPDIR}/urls.txt" | while read line || [[ -n $line ]];
do
    #Check URLs against collected archive
    if ! grep -q "${line}" "${ArchiveFile}"; then
        # url is not in file
        loud "# Getting page of RFC"
        link="${line}"
        wget "${line}" --convert-links -O "${TEMPDIR}/tmphtml"
        description=$(cat "${TEMPDIR}/tmphtml" | sed -n '/<pre/,/<\/pre>/p')
        rm "${TEMPDIR}/tmphtml"
        title=$(echo "${description}" | fmt -w 1111 | grep -B 2 -e "^AGENCY" | head -n 1)
        # add to rss
        loud "# Adding to RSS"
        rss_gen_send 
        # save to archive
        echo "${link}" >> "${ArchiveFile}"
        # reset variables
        link=""
        description=""
        title=""
    fi
done


# clean up
loud "# Cleaning up"
rm "${TEMPDIR}/dom.html"
rm "${TEMPDIR}/articles.html"
rm "${TEMPDIR}/urls.txt"
rmdir "${TEMPDIR}"

