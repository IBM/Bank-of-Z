#!/bin/sh
# =============================================================================
# Script  : addcert.sh
# Summary : Create RACF keyring and server certificate for Bank of Z.
#           Run once per ZVDT image (called by setup-common.sh).
#
# Liberty (z/OS Connect + frontend) uses the keyring directly:
#   keystoreType="JCERACFKS"
#   keystoreFile="safkeyring://IBMUSER/BOZRING"
#
# The Node.js Docker-path server needs PEM files on USS.  These are
# exported at the end of this script into /u/ibmuser/boz-certs/.
# The intermediate RACF datasets used for export are deleted immediately
# after use so no copy of the private key persists in DASD.
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
dnsname=$(hostname 2>/dev/null)
expire=$(tsocmd "RACDCERT CERTAUTH LIST(LABEL('VSICA'))" \
 | awk '/End Date:/ {gsub("/","-",$3); print $3}')

# certificate & keyring
# KEYUSAGE: HANDSHAKE (TLS key exchange) + DATAENCRYPT (TLS bulk encryption)
# only — no CERTSIGN (would make this cert a CA) or DOCSIGN (irrelevant for TLS).
# ALTNAME includes both the IP and DNS hostname so browsers doing name-based
# verification (Safari, etc.) find a matching SAN.
tsocmd "RACDCERT GENCERT \
 ID($userid) \
 SUBJECTSDN(CN('$cn') O('IBM') OU('$ou') C('US')) \
 SIGNWITH(CERTAUTH LABEL('VSICA')) \
 NOTAFTER(DATE($expire)) \
 ALTNAME(IP($ipaddr) DOMAIN('$dnsname')) \
 WITHLABEL('$label') \
 SIZE(2048) \
 KEYUSAGE(HANDSHAKE DATAENCRYPT) \
 TRUST"
tsocmd "RACDCERT ID($userid) ADDRING($ring)"
tsocmd "RACDCERT ID($userid) \
 CONNECT(CERTAUTH LABEL('VSICA') RING($ring) USAGE(CERTAUTH))"
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

# Export cert and key to PEM files on USS for the Node.js Docker-path server.
# Liberty on z/OS uses safkeyring:// directly and does not need these files.
# The intermediate RACF datasets are deleted immediately after use.
if test $rc -eq 0
then
  outdir="/u/$(echo $userid | tr '[:upper:]' '[:lower:]')/boz-certs"
  mkdir -p "$outdir"

  # Export the signed server cert as PEM
  tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
   DSN('$userid.BOZ.CERT') FORMAT(CERTB64)"
  cp "//'${userid}.BOZ.CERT'" "$outdir/server.crt"
  iconv -f IBM-1047 -t ISO8859-1 "$outdir/server.crt" > "$outdir/server.crt.pem"
  mv "$outdir/server.crt.pem" "$outdir/server.crt"
  tsocmd "DELETE ('$userid.BOZ.CERT')" >/dev/null 2>&1

  # Export the private key as PKCS12, extract to PEM, then delete the dataset
  tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
   DSN('$userid.BOZ.KEY') FORMAT(PKCS12DER) PASSWORD('password')"
  if command -v openssl >/dev/null 2>&1; then
    openssl pkcs12 -in "//'${userid}.BOZ.KEY'" -nocerts -nodes \
      -passin pass:password -out "$outdir/server.key" 2>/dev/null
  else
    cp "//'${userid}.BOZ.KEY'" "$outdir/server.key"
  fi
  tsocmd "DELETE ('$userid.BOZ.KEY')" >/dev/null 2>&1

  chmod 600 "$outdir/server.key"
  echo "Cert and key exported to $outdir (for Node.js Docker path only)"
  echo "Liberty on z/OS uses safkeyring://IBMUSER/BOZRING directly."
fi

exit $rc
