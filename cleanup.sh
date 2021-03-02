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
DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd  )"
cd $DIR
source config.sh
DOMAIN="$CERTBOT_DOMAIN"
echo "Received request for" "$DOMAIN"

## Get current list (updating may alter rrid, etc)
curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$APIKEY&domain=$DOMAIN" > $CACHE_DIR/$DOMAIN.xml

## Check for existing ACME record
RECORD_ID=`xmllint --xpath "//namesilo/reply/resource_record/record_id[../host/text() = '_acme-challenge.$DOMAIN' ]/text()" $CACHE_DIR/$DOMAIN.xml 2>/dev/null`
if [ -n "$RECORD_ID" ]; then
	## Update DNS record in Namesilo:
	curl -s "https://www.namesilo.com/api/dnsDeleteRecord?version=1&type=xml&key=$APIKEY&domain=$DOMAIN&rrid=$RECORD_ID" > $RESPONSE_FILE
	RESPONSE_CODE=`xmllint --xpath "//namesilo/reply/code/text()"  $RESPONSE_FILE`
	## Process response, maybe wait

	case $RESPONSE_CODE in
		300)
			echo "ACME challenge record successfully removed"
			;;
		280)
			RESPONSE_DETAIL=`xmllint --xpath "//namesilo/reply/detail/text()"  $RESPONSE_FILE`
			echo "Record removal failed."
			echo "Reason: $RESPONSE_DETAIL"
			echo "Domain: $DOMAIN"
			echo "Record ID: $RECORD_ID"
			;;
		*)
			RESPONSE_DETAIL=`xmllint --xpath "//namesilo/reply/detail/text()"  $RESPONSE_FILE`
			echo "Return code: $RESPONSE_CODE"
			echo "Reason: $RESPONSE_DETAIL"
			echo "Domain: $DOMAIN"
			echo "Record ID: $RECORD_ID"
			;;
	esac

fi

[ -f $RESPONSE_FILE ] && rm $RESPONSE_FILE
[ -f $CACHE_DIR/$DOMAIN.xml ] && rm $CACHE_DIR/$DOMAIN.xml
