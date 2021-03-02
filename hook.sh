#!/bin/bash
# NameSileCertbot-DNS-01 0.2.2
## https://stackoverflow.com/questions/59895
set -x
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE"  ]; do
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /*  ]] && SOURCE="$DIR/$SOURCE"
done
cd "$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"
source config.sh

DOMAIN="$CERTBOT_DOMAIN"
VALIDATION="$CERTBOT_VALIDATION"
echo "Received request for" "$DOMAIN"

## Get the XML & record ID
curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$APIKEY&domain=$DOMAIN" > $CACHE_DIR/$DOMAIN.xml

## Check for existing ACME record
RECORD_ID=`xmllint --xpath "//namesilo/reply/resource_record/record_id[../host/text() = '_acme-challenge.$DOMAIN' ]/text()" $CACHE_DIR/$DOMAIN.xml 2>/dev/null`
if [ -n "$RECORD_ID" ]; then
	ACTION=Update
	API_STRING="dnsUpdateRecord?rrid=$RECORD_ID&"
else
	ACTION=Addition
	API_STRING='dnsAddRecord?rrtype=TXT&'
fi

curl -s "https://www.namesilo.com/api/${API_STRING}version=1&type=xml&key=$APIKEY&domain=$DOMAIN&rrhost=_acme-challenge&rrvalue=$VALIDATION&rrttl=3600" >$RESPONSE_FILE
RESPONSE_CODE=`xmllint --xpath "//namesilo/reply/code/text()"  $RESPONSE_FILE`

## Process response, maybe wait
case $RESPONSE_CODE in
	300)
		echo "$ACTION successful. Please wait 15 minutes for validation..."
		# Records are published every 15 minutes. Wait for 16 minutes, and then proceed.
		for (( i=0; i<60; i++ )); do
			echo "Minute" $i
			#nslookup -type=TXT _acme-challenge.$DOMAIN | grep -oP '(?<=text \= ").*(?="$)'
			sleep 60s
		done
		;;
	280)
		RESPONSE_DETAIL=`xmllint --xpath "//namesilo/reply/detail/text()"  $RESPONSE_FILE`
		echo "$ACTION aborted, please check your NameSilo account."
		echo "Reason: $RESPONSE_DETAIL"
		echo "Domain: $DOMAIN"
		echo "Record ID: $RECORD_ID"
		;;
	*)
		RESPONSE_DETAIL=`xmllint --xpath "//namesilo/reply/detail/text()"  $RESPONSE`
		echo "Return code: $RESPONSE_CODE"
		echo "Reason: $RESPONSE_DETAIL"
		echo "Domain: $DOMAIN"
		echo "Record ID: $RECORD_ID"
		;;
esac

