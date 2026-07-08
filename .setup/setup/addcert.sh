#!/bin/sh
# =============================================================================
# Script  : addcert.sh
# Summary : Create RACF keyring and server certificate for Bank of Z Node
#           frontend server. Run once per ZVDT image.
#
# The Node.js server references the keyring via:
#   keystoreType="JCERACFKS"
#   keystoreFile="safkeyring://IBMUSER/BOZRING"
#   keystorePass="password"
# =============================================================================

## CUSTOMIZE ##
## uppercase, 1 word
userid=IBMUSER
ring=BOZRING

## mixed case, multi word
label='BoZ'
cn='Bank of Z'
ou='IBM BoZ'

## FIXED ##
profile=$userid.$ring.LST

# safety net, not sure if class is active or not
tsocmd "SETROPTS GENERIC(SERVAUTH)" \
 >/dev/null 2>&1
tsocmd "SETROPTS CLASSACT(SERVAUTH) RACLIST(SERVAUTH)" \
 >/dev/null 2>&1

# cleanup, might fail
tsocmd "RACDCERT ID($userid) DELRING($ring)" \
 >/dev/null 2>&1
tsocmd "RACDCERT ID($userid) DELETE(LABEL('$label'))" \
 >/dev/null 2>&1
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH" \
 >/dev/null 2>&1
tsocmd "PERMIT $profile CLASS(RDATALIB) ID($userid) DELETE" \
 >/dev/null 2>&1
tsocmd "RDELETE RDATALIB $profile" \
 >/dev/null 2>&1
tsocmd "SETROPTS RACLIST(RDATALIB) REFRESH" \
 >/dev/null 2>&1

# system variables
ipaddr=$(netstat -h 2>/dev/null | awk '/ OSA/ {print $1}')       # IPv4
test "$ipaddr" = "IntfName:" && ipaddr=$(netstat -h 2>/dev/null \
 | awk '/ OSA/ {f=1; next} f {print $2; exit}')                  # IPv6
expire=$(tsocmd "RACDCERT CERTAUTH LIST(LABEL('VSICA'))" \
 | awk '/End Date:/ {gsub("/","-",$3); print $3}')

# certificate & keyring
tsocmd "RACDCERT GENCERT \
 ID($userid) \
 SUBJECTSDN(CN('$cn') O('IBM') OU('$ou') C('US')) \
 SIGNWITH(CERTAUTH LABEL('VSICA')) \
 NOTAFTER(DATE($expire)) \
 ALTNAME(IP($ipaddr)) \
 WITHLABEL('$label') \
 SIZE(2048) \
 TRUST"
tsocmd "RACDCERT ID($userid) ADDRING($ring)"
tsocmd "RACDCERT ID($userid) \
 CONNECT(CERTAUTH LABEL('VSICA') RING($ring) USAGE(PERSONAL))"
tsocmd "RACDCERT ID($userid) \
 CONNECT(LABEL('$label') RING($ring) DEFAULT)"
rc=$?
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH"

# usage permit
if test $rc -eq 0
then
  tsocmd "RDEFINE RDATALIB $profile"
  tsocmd "PERMIT $profile CLASS(RDATALIB) ID($userid) ACCESS(CONTROL)"
  rc=$?
  tsocmd "SETROPTS RACLIST(RDATALIB) REFRESH"
fi

# Export cert and key to PEM files on USS for Node.js to read
if test $rc -eq 0
then
  outdir="/u/$userid/boz-certs"
  mkdir -p "$outdir"

  # Export the signed server cert as PEM
  tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
   DSN('$userid.BOZ.CERT') FORMAT(CERTB64)"
  # Convert EBCDIC dataset to ASCII PEM file
  cp "//'${userid}.BOZ.CERT'" "$outdir/server.crt"
  iconv -f IBM-1047 -t ISO8859-1 "$outdir/server.crt" > "$outdir/server.crt.pem"
  mv "$outdir/server.crt.pem" "$outdir/server.crt"

  # Export the private key as PEM
  tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
   DSN('$userid.BOZ.KEY') FORMAT(PKCS12DER) PASSWORD('password')"
  # Convert PKCS12 to PEM key using openssl if available
  if command -v openssl >/dev/null 2>&1; then
    openssl pkcs12 -in "//'${userid}.BOZ.KEY'" -nocerts -nodes \
      -passin pass:password -out "$outdir/server.key" 2>/dev/null
  else
    cp "//'${userid}.BOZ.KEY'" "$outdir/server.key"
  fi

  chmod 600 "$outdir/server.key"
  echo "Cert and key exported to $outdir"
  echo "Start Node server with:"
  echo "  SSL_CERT=$outdir/server.crt SSL_KEY=$outdir/server.key node server.js"
fi

exit $rc
