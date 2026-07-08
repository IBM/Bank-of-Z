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
exit $rc
