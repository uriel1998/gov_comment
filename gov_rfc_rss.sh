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

# MODIFY THIS, OBVIOUSLY. For mastodon posting
account_using=USGovComment@faithcollapsing.com



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
self_link=https://raw.githubusercontent.com/uriel1998/gov_comment/refs/heads/master/rss_output/gov_rfc_rss.xml
link=""
description=""
title=""
category=""
filedtime=""
ai_description=""
due_time=""
 

# Now we can set these
ArchiveFile="${SCRIPT_DIR}/retrieved_urls.txt"
export RSSSavePath="${SCRIPT_DIR}/rss_output/gov_rfc_rss.xml"

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
        printf '    <title>US Federal Government Request For Comments</title>\n' >> "${RSSSavePath}"
        printf '    <description>This pulls from a search of the Federal Register to pull requests for comments and make them readable. </description>\n' >> "${RSSSavePath}"
        printf '    <link rel="self" href="%s" />\n' "${self_link}" >> "${RSSSavePath}"
        printf '  </channel>\n' >> "${RSSSavePath}"
        printf '</rss>\n' >> "${RSSSavePath}"    

    fi
    TITLE="${title}"
    LINK=$(printf "href=\"%s\"" "${link}")
    DATE="${filedtime}"
    DESC=$(printf "&lt;p&gt;\n%s\n&lt;/p&gt;&lt;p&gt;More info at: &lt;a href=&quot;%s&quot;&gt;%s&lt;/a&gt;&lt;/p&gt;" "${description}" "${link}" "${link}")
    GUID="${link}" 
    loud "[info] Adding entry to RSS feed"
    xmlstarlet ed -L \
    -s "//channel" -t elem -n item -v "" \
    -s "//channel/item[last()]" -t elem -n title -v "$TITLE" \
    -s "//channel/item[last()]" -t elem -n link -v "$LINK" \
    -s "//channel/item[last()]" -t elem -n pubDate -v "$DATE" \
    -s "//channel/item[last()]" -t elem -n description -v "$DESC" \
    -s "//channel/item[last()]" -t elem -n category -v "${category}" \
    -s "//channel/item[last()]" -t elem -n guid -v "$GUID" \
    -d "//channel/item[position()>100]" "${RSSSavePath}" ;

}

convert_filedtime_rfc2822() {
    local input="${@}"
    local date_str time_str datetime_str
 
    # Extract the date and time using grep and sed
    date_str=$(echo "${input}" | grep -oP 'Filed \K[0-9-]+')
    time_str=$(echo "${input}" | grep -oP '[0-9]{1,2}:[0-9]{2} [ap]m')
 
    if [[ -n "$date_str" && -n "$time_str" ]]; then
        # Convert date format from M-D-YY to MM-DD-YYYY
        month=$(echo "$date_str" | cut -d'-' -f1)
        day=$(echo "$date_str" | cut -d'-' -f2)
        year=$(echo "$date_str" | cut -d'-' -f3)

        # Ensure month and day have leading zeroes if needed
        month=$(printf "%02d" "$month")
        day=$(printf "%02d" "$day")

        # Convert 2-digit year to 4-digit (assuming 2000+)
        if [[ "$year" -lt 100 ]]; then
            year=$((2000 + year))
        fi

        # Convert time to 24-hour format
        datetime_str="$month/$day/$year $time_str"
        formatted_datetime=$(date -d "$datetime_str" +"%a, %d %b %Y %H:%M:%S %z" 2>/dev/null)
 
        if [[ -n "$formatted_datetime" ]]; then
            loud "FiledTime: $formatted_datetime"
            filedtime="${formatted_datetime}"
        else
            loud "Error: Invalid date/time format."
            return 1
        fi
    else
        echo "Error: Date or time not found."
        return 1
    fi
}

function toot_send {
    tempfile=$(mktemp)
    if [ "$title" == "$link" ];then
        title=""
    fi
    loud "LINK ${link}"
    # HARDCODED
    binary=$(which toot)
        
    #Yes, I know the URL length doesn't actually count against it.  Just 
    #reusing code here.
    bigstring=$(printf "%s \n%s \n%s\n" "${title}" "${description}" "${link}")
    
    if [ ${#bigstring} -lt 500 ];then 
        printf "%s \n%s \n%s\n" "${title}" "${description}" "${link}"  > "${tempfile}"
    else
        outstring=$(printf "%s \n%s\n" "$description" "$link")
        if [ ${#outstring} -lt 500 ]; then
            printf "%s \n%s\n" "${description}" "${link}" > "${tempfile}"
        else
            outstring=$(printf "%s \n%s\n" "$title" "$link")
            if [ ${#outstring} -lt 500 ]; then
                printf "%s \n%s\n" "${title}" "${link}" > "${tempfile}"
            fi
        fi
    fi

    cw=$(echo "-p \"uspol\"")
    
    postme=$(printf "cat %s | %s post %s -u %s" "${tempfile}" "$binary" "${cw}" "${account_using}")
    eval ${postme}
    
    if [ -f "${tempfile}" ];then
        rm "${tempfile}"
    fi
    
}


get_ai_summary() {
    ai_description=""
    due_time=""
    # using mods here, free tier, so need to check errorcode afterward
    ai_description=$(echo "${description}" | mods "In less than 300 characters including spaces, summarize the issue that comments are being sought for. Use no more than 300 characters for the summary.  Separate from the 300 character summary, in a new paragraph, place the due date for comments using the format COMMENTS_DUE: DD MMM YYYY" --quiet --word-wrap 80 )
    
    if [ $? != 0 ] || [ ai_description != "" ];then
        loud "# Got summary successfully."
        due_time=$(echo "${ai_description}" | tail -n 1 | awk -F ": " '{print $2}')
        description=$(echo "${ai_description}")
        echo "${description}"
        echo "${due_time}"
    else
        loud "## ERROR GETTING AI SUMMARY."
        loud "## Returned: ${ai_description}"
    fi
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
${chromium_bin} --headless --dump-dom --virtual-time-budget=10000 --timeout=10000 "https://www.govinfo.gov/app/search/%7B%22query%22%3A%22%5C%22request%20for%20comment%5C%22%22%2C%22offset%22%3A0%2C%22sortBy%22%3A%222%22%2C%22pageSize%22%3A25%7D" > "${TEMPDIR}/dom.html"

#Use sed to extract articles
loud "# Extracting articles"
cat "${TEMPDIR}/dom.html" | sed 's/>/>\n/g' | sed -n '/<ol/,/<\/ol>/p' | sed -n '/<article/,/<\/article>/p' > "${TEMPDIR}/articles.html"

#Use awk to extract urls of text versions
loud "# Extracting urls of actual articles"
cat "${TEMPDIR}/articles.html" | grep -e "/html/" | awk -F '"' '{print "https://www.govinfo.gov" $4}' > "${TEMPDIR}/urls.txt"

counter=0
cat "${TEMPDIR}/urls.txt" | while read line || [[ -n $line ]];
do
    if [ $counter -gt 2 ];then
        break
    fi
    #Check URLs against collected archive
    if ! grep -q "${line}" "${ArchiveFile}"; then
        # url is not in file
        let counter++
        loud "# Incrementing run counter to $counter"
        loud "# Getting page of RFC"
        link="${line}"
        wget "${line}" --convert-links -O "${TEMPDIR}/tmphtml"
        description=$(cat "${TEMPDIR}/tmphtml" | sed -n '/<pre/,/<\/pre>/p' |recode ascii..html )
        rm "${TEMPDIR}/tmphtml"
        title=$(echo "${description}" | fmt -w 1111 | grep -B 2 -e "^AGENCY" | head -n 1)
        category=$(echo "${description}" | fmt -w 1111 | grep -e "^AGENCY" | awk -F ': ' '{print $2}')
        tempstring=$(echo "${description}" | grep -e "FR Doc" | grep -e "Filed" )
        convert_filedtime_rfc2822 "${tempstring}"
        loud "# getting AI summary"
        get_ai_summary
        # add to rss
        loud "# Adding to RSS"
        rss_gen_send 
        loud "# Sending to Mastodon"
        toot_send
        # save to archive
        echo "${link}" >> "${ArchiveFile}"
        # reset variables
        link=""
        description=""
        title=""
        category=""
        due_time=""
        ai_description=""
        # To doublecheck that we aren't exceeding free tier API rates
        loud "# Thirty second nap."
        sleep 30
    fi
done


# clean up
loud "# Cleaning up"
rm "${TEMPDIR}/dom.html"
rm "${TEMPDIR}/articles.html"
rm "${TEMPDIR}/urls.txt"
rmdir "${TEMPDIR}"

