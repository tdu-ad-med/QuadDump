#!/bin/sh

# 証明書の取得
CERT_LIST=$(\
	security find-identity -p codesigning -v login.keychain |\
	grep -oE '"[^"]+"' | sed 's/"//g'
)

# 取得した証明書からDEVELOPMENT_TEAMの値を取得
echo ""
echo $CERT_LIST | while read CERT; do
	OU=$(\
		security find-certificate -p -c "$CERT" |\
		openssl x509 -noout -subject |\
		grep -oE "OU=[a-zA-Z0-9]+" | sed "s/^OU=//"
	)
	echo "$CERT"
	echo "DEVELOPMENT_TEAM=$OU"
	echo ""
done
