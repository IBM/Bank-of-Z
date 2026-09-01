#!/bin/env bash
# =============================================================================
# Script  : gencert-eku.sh
# Summary : Generate a TLS server certificate with EKU serverAuth (OID
#           1.3.6.1.5.5.7.3.1) signed by VSICA, with the private key
#           remaining in the RACF keyring at all times.
#
# Approach (re-sign existing RACF cert - private key never leaves RACF):
#   1. RACDCERT GENCERT SIGNWITH(CERTAUTH LABEL('$ca_label')) - RACF generates
#      keypair and a VSICA-signed cert.  Private key stays in RACF.
#   2. dcp export the cert as CERTB64 (PEM) to USS.
#   3. Bouncy Castle reads the public key from the PEM, builds a new
#      TBSCertificate with EKU serverAuth + SANs + 397-day validity, and
#      re-signs it with VSICA's key (exported as PKCS12DER, deleted after).
#   4. dcp the new DER cert back to a RACF dataset.
#   5. RACDCERT ADD FORMAT(CERTDER) - RACF matches the new cert to the
#      private key it already holds (same public key).
#   6. Connect cert to ${ZOS_KEYRING} as DEFAULT.
#   7. Liberty uses safkeyring://${ZOS_ADMIN_USER}/${ZOS_KEYRING} (JCERACFKS).
#
# Called by addcert.sh after the keyring scaffold is in place.
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[GENCERT]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

set -e  # Exit immediately on any non-zero return code

userid=${ZOS_ADMIN_USER}
ca_label=${ZOS_CA_LABEL}
ring=${ZOS_KEYRING}
label='BoZ'

# -----------------------------------------------------------------------
# Resolve tools - JAVA_HOME and PYTHON_HOME must be set by the environment
# (sourced from config.yaml via setenv.sh).
# -----------------------------------------------------------------------
if [ -z "${JAVA_HOME:-}" ]; then
  print_error "JAVA_HOME is not set"; exit 1
fi
JAVA="$JAVA_HOME/bin/java"
JAVAC="$JAVA_HOME/bin/javac"
if [ ! -x "$JAVA" ]; then
  print_error "java not found at $JAVA"; exit 1
fi

if [ -n "${PYTHON_HOME:-}" ] && [ -x "$PYTHON_HOME/bin/python3" ]; then
  PYTHON="$PYTHON_HOME/bin/python3"
elif [ -x /usr/lpp/IBM/cyp/v3r14/pyz/bin/python3 ]; then
  PYTHON=/usr/lpp/IBM/cyp/v3r14/pyz/bin/python3
else
  PYTHON=$(command -v python3 2>/dev/null) || { print_error "python3 not found"; exit 1; }
fi

# Ensure ZOAU tools (dcp, tsocmd, etc.) are on PATH.
# Primary: use $ZOAU_HOME (set from config.yaml, default /usr/lpp/IBM/zoau/v1r4).
# Fallback: pre-1.3 install paths on older ZVDT images.
if [ -n "${ZOAU_HOME:-}" ] && [ -x "$ZOAU_HOME/bin/dcp" ]; then
  export PATH="$ZOAU_HOME/bin:$PATH"
elif [ -x /usr/lpp/IBM/zoau/bin/dcp ]; then
  export PATH="/usr/lpp/IBM/zoau/bin:$PATH"
elif [ -x /usr/lpp/IBM/zoau/v1r4/bin/dcp ]; then
  export PATH="/usr/lpp/IBM/zoau/v1r4/bin:$PATH"
elif [ -x /usr/lpp/IBM/zoau/v1r3/bin/dcp ]; then
  export PATH="/usr/lpp/IBM/zoau/v1r3/bin:$PATH"
elif [ -x /usr/lpp/IBM/zoautil/bin/dcp ]; then
  export PATH="/usr/lpp/IBM/zoautil/bin:$PATH"
fi
DCP=$(command -v dcp 2>/dev/null) || { print_error "dcp (ZOAU) not found on PATH"; exit 1; }

_TOOLS_DIR="${SANDBOX_DIR}/../tools"
BCJAR=$(ls "$_TOOLS_DIR"/*/lib/plugins/bcprov-*.jar 2>/dev/null | head -1)
if [ -z "$BCJAR" ]; then
  print_error "bcprov-*.jar not found under $_TOOLS_DIR"; exit 1
fi

# -----------------------------------------------------------------------
# Guard: verify IP and DNS can be determined
# -----------------------------------------------------------------------
# TCP/IP NETSTAT HOME output differs between z/OS levels.  Select the first
# non-loopback IPv4 address rather than relying on a particular table layout.
ipaddr=$(netstat -h 2>/dev/null |
  awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && $1 != "127.0.0.1" { print $1; exit }')
dnsname=$(hostname 2>/dev/null)

if [ -z "$ipaddr" ] || [ -z "$dnsname" ]; then
  print_error "Could not determine IP ($ipaddr) or DNS ($dnsname)"
  exit 1
fi

expire=$(tsocmd "RACDCERT CERTAUTH LIST(LABEL('$ca_label'))" \
  | awk '/End Date:/ {gsub("/","-",$3); print $3}')

print_info "IP=$ipaddr  DNS=$dnsname  VSICA expire=$expire"
print_info "Private key stays in RACF keyring throughout."

# Random passwords via Python
CA_PASS=$($PYTHON -c "import secrets; print(secrets.token_urlsafe(18))")

# Race-safe temp dir - chmod after mkdir to guarantee 700 regardless of umask
TMPDIR=${TMPDIR:-/tmp}/boz-cert-$$
mkdir -p "$TMPDIR"
chmod 700 "$TMPDIR"
trap 'rm -rf "$TMPDIR"
  tsocmd "DELETE (\047${userid}.BOZ.CAKEY\047)" >/dev/null 2>&1 || true
  tsocmd "DELETE (\047${userid}.BOZ.CERTB64\047)" >/dev/null 2>&1 || true
  tsocmd "DELETE (\047${userid}.BOZ.NEWCERT\047)" >/dev/null 2>&1 || true' EXIT

# -----------------------------------------------------------------------
# 1. Generate keypair + cert in RACF, signed by VSICA.
#    Private key is generated inside RACF and never leaves.
# -----------------------------------------------------------------------
print_info "Generating keypair in RACF (SIGNWITH VSICA)..."
tsocmd "RACDCERT GENCERT \
  ID($userid) \
  SUBJECTSDN(CN('Bank of Z') O('IBM') OU('IBM BoZ') C('US')) \
  SIGNWITH(CERTAUTH LABEL('$ca_label')) \
  NOTAFTER(DATE($expire)) \
  ALTNAME(IP($ipaddr) DOMAIN('$dnsname')) \
  WITHLABEL('$label') \
  SIZE(2048) \
  KEYUSAGE(HANDSHAKE DATAENCRYPT) \
  TRUST"
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH"

# -----------------------------------------------------------------------
# 3. Export the cert (public side only) as CERTB64 (PEM) to USS via dcp.
#    dcp is used because cp "//dataset" fails for CERTB64/CERTDER exports
#    on this RACF version - dcp handles the dataset-to-USS copy correctly.
# -----------------------------------------------------------------------
print_info "Exporting cert as PEM for re-signing..."
tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
  DSN('${userid}.BOZ.CERTB64') FORMAT(CERTB64)"
$DCP "${userid}.BOZ.CERTB64" "$TMPDIR/boz-orig.pem"
# Java (ResignCert) handles Cp1047/EBCDIC decoding directly - no conversion needed here.

# -----------------------------------------------------------------------
# 4. Export VSICA private key (PKCS12DER) so Bouncy Castle can re-sign.
#    Dataset deleted in EXIT trap.
# -----------------------------------------------------------------------
print_info "Exporting VSICA CA for re-signing..."
tsocmd "RACDCERT EXPORT(LABEL('$ca_label')) CERTAUTH \
  DSN('${userid}.BOZ.CAKEY') FORMAT(PKCS12DER) PASSWORD('${CA_PASS}')"
cp "//'${userid}.BOZ.CAKEY'" "$TMPDIR/vsica.p12"

# -----------------------------------------------------------------------
# 5. Write ResignCert.java via Python (avoids _BPXK_AUTOCVT EBCDIC)
# -----------------------------------------------------------------------
$PYTHON - "$TMPDIR/ResignCert.java" << 'PYEOF'
import sys
src = r"""
// Reads public key from an existing RACF-generated cert (PEM), re-signs it
// with VSICA adding EKU serverAuth + SANs.  Private key never leaves RACF.
import org.bouncycastle.asn1.ASN1EncodableVector;
import org.bouncycastle.asn1.ASN1Integer;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.DERBitString;
import org.bouncycastle.asn1.DERNull;
import org.bouncycastle.asn1.DERSequence;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.AlgorithmIdentifier;
import org.bouncycastle.asn1.x509.ExtendedKeyUsage;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.asn1.x509.ExtensionsGenerator;
import org.bouncycastle.asn1.x509.GeneralName;
import org.bouncycastle.asn1.x509.GeneralNames;
import org.bouncycastle.asn1.x509.KeyPurposeId;
import org.bouncycastle.asn1.x509.KeyUsage;
import org.bouncycastle.asn1.x509.SubjectPublicKeyInfo;
import org.bouncycastle.asn1.x509.TBSCertificate;
import org.bouncycastle.asn1.x509.Time;
import org.bouncycastle.asn1.x509.V3TBSCertificateGenerator;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.math.BigInteger;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.Security;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Date;

public class ResignCert {
    static final ASN1ObjectIdentifier EKU_SERVER_AUTH =
        new ASN1ObjectIdentifier("1.3.6.1.5.5.7.3.1");
    static final ASN1ObjectIdentifier SHA256_WITH_RSA =
        new ASN1ObjectIdentifier("1.2.840.113549.1.1.11");

    // CA/Browser Forum maximum validity periods (CAB Forum ballot SC-081):
    //   Until 2027-03-14 : 200 days (effective 2026-03-15)
    //   2027-03-15 onward: 100 days
    //   2029-03-15 onward:  47 days
    // Update cutoff dates/limits below when the schedule changes.
    static final long DAYS_200 = 200L * 24 * 60 * 60 * 1000;
    static final long DAYS_100 = 100L * 24 * 60 * 60 * 1000;
    static final long DAYS_47  =  47L * 24 * 60 * 60 * 1000;
    static final LocalDate CUTOFF_100 = LocalDate.of(2027, 3, 15);
    static final LocalDate CUTOFF_47  = LocalDate.of(2029, 3, 15);

    static long maxValidityMs() {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        if (!today.isBefore(CUTOFF_47))  return DAYS_47;
        if (!today.isBefore(CUTOFF_100)) return DAYS_100;
        return DAYS_200;
    }

    public static void main(String[] args) throws Exception {
        // args: origPem caP12 caPass outDer ip dns notAfter
        String origPem  = args[0];
        String caP12    = args[1]; String caPass = args[2];
        String outDer   = args[3];
        String ip       = args[4]; String dns    = args[5];
        String notAfter = args[6];

        Security.addProvider(new BouncyCastleProvider());

        // Load VSICA CA keystore
        KeyStore caKs = KeyStore.getInstance("PKCS12");
        try (InputStream in = new FileInputStream(caP12)) {
            caKs.load(in, caPass.toCharArray());
        }
        String caAlias  = caKs.aliases().nextElement();
        PrivateKey caKey = (PrivateKey) caKs.getKey(caAlias, caPass.toCharArray());
        X509Certificate caCert = (X509Certificate) caKs.getCertificate(caAlias);

        // Parse the RACF-exported cert.  dcp copies EBCDIC bytes (Cp1047)
        // from the RACF dataset - try Cp1047 first, fall back to ISO-8859-1.
        byte[] pemBytes = Files.readAllBytes(Paths.get(origPem));
        String decoded1047 = new String(pemBytes, "Cp1047");
        String pemStr = decoded1047.contains("-----BEGIN") ? decoded1047
                      : new String(pemBytes, "ISO-8859-1");
        pemStr = pemStr.replaceAll("-----[^\n]+-----", "").replaceAll("\\s", "");
        byte[] derBytes = Base64.getDecoder().decode(pemStr);
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        X509Certificate orig  = (X509Certificate) cf.generateCertificate(
            new ByteArrayInputStream(derBytes));
        System.out.println("Original subject : " + orig.getSubjectX500Principal());
        System.out.println("Original key algo: " + orig.getPublicKey().getAlgorithm());

        // Validity: 5-min skew tolerance; cap at CAB Forum limit for today's date
        Date notBefore    = new Date(System.currentTimeMillis() - 5 * 60 * 1000);
        Date requestedEnd = Date.from(
            LocalDate.parse(notAfter).atStartOfDay(ZoneOffset.UTC).toInstant());
        Date cappedEnd    = new Date(notBefore.getTime() + maxValidityMs());
        Date notAfterDate = requestedEnd.before(cappedEnd) ? requestedEnd : cappedEnd;
        System.out.println("Validity: " + notBefore + " -> " + notAfterDate);

        // Reuse subject + public key from original RACF-generated cert
        X500Name subject = X500Name.getInstance(orig.getSubjectX500Principal().getEncoded());
        X500Name issuer  = X500Name.getInstance(caCert.getSubjectX500Principal().getEncoded());
        SubjectPublicKeyInfo spki = SubjectPublicKeyInfo.getInstance(
            orig.getPublicKey().getEncoded());

        // Extensions: SANs, KeyUsage, EKU serverAuth
        ExtensionsGenerator exts = new ExtensionsGenerator();
        exts.addExtension(Extension.subjectAlternativeName, false,
            new GeneralNames(new GeneralName[]{
                new GeneralName(GeneralName.iPAddress, ip),
                new GeneralName(GeneralName.dNSName,   dns)
            }));
        exts.addExtension(Extension.keyUsage, true,
            new KeyUsage(KeyUsage.digitalSignature | KeyUsage.keyEncipherment));
        exts.addExtension(Extension.extendedKeyUsage, false,
            new ExtendedKeyUsage(KeyPurposeId.getInstance(EKU_SERVER_AUTH)));

        AlgorithmIdentifier sigAlg =
            new AlgorithmIdentifier(SHA256_WITH_RSA, DERNull.INSTANCE);
        V3TBSCertificateGenerator tbsGen = new V3TBSCertificateGenerator();
        tbsGen.setSerialNumber(new ASN1Integer(new BigInteger(159, new SecureRandom())));
        tbsGen.setIssuer(issuer);
        tbsGen.setSubject(subject);
        tbsGen.setStartDate(new Time(notBefore));
        tbsGen.setEndDate(new Time(notAfterDate));
        tbsGen.setSubjectPublicKeyInfo(spki);
        tbsGen.setExtensions(exts.generate());
        tbsGen.setSignature(sigAlg);
        TBSCertificate tbs = tbsGen.generateTBSCertificate();

        Signature sig = Signature.getInstance("SHA256withRSA");
        sig.initSign(caKey);
        sig.update(tbs.getEncoded());
        byte[] sigBytes = sig.sign();

        ASN1EncodableVector v = new ASN1EncodableVector();
        v.add(tbs); v.add(sigAlg); v.add(new DERBitString(sigBytes));
        byte[] newDer = new DERSequence(v).getEncoded();

        // Verify chain before writing
        X509Certificate newCert = (X509Certificate) cf.generateCertificate(
            new ByteArrayInputStream(newDer));
        newCert.verify(caCert.getPublicKey());
        System.out.println("Signature verified against VSICA.");
        System.out.println("EKU: " + newCert.getExtendedKeyUsage());

        try (FileOutputStream fos = new FileOutputStream(outDer)) {
            fos.write(newDer);
        }
        System.out.println("New cert DER written: " + outDer + " (" + newDer.length + " bytes)");
    }
}
"""
with open(sys.argv[1], 'wb') as f:
    f.write(src.encode('iso-8859-1'))
PYEOF

print_info "Compiling ResignCert.java..."
$JAVAC -cp "$BCJAR" "$TMPDIR/ResignCert.java" -d "$TMPDIR"

# -----------------------------------------------------------------------
# 6. Run ResignCert - produces a DER cert with EKU, signed by VSICA,
#    containing the SAME public key as the RACF-held private key.
# -----------------------------------------------------------------------
print_info "Re-signing cert with EKU serverAuth..."
$JAVA -cp "$TMPDIR:$BCJAR" ResignCert \
  "$TMPDIR/boz-orig.pem" \
  "$TMPDIR/vsica.p12" "$CA_PASS" \
  "$TMPDIR/boz-new.der" \
  "$ipaddr" "$dnsname" "$expire"

test -s "$TMPDIR/boz-new.der" || {
  print_error "boz-new.der not produced"; exit 1; }

# -----------------------------------------------------------------------
# 7. Copy new DER cert to RACF dataset and IMPORT it.
#    RACF will match it to the private key already held for label '$label'
#    because they share the same public key.
# -----------------------------------------------------------------------
print_info "Importing re-signed cert into RACF..."
# ALLOC MOD creates the dataset if absent or reuses it if present - no DELETE needed
# since dcp -B overwrites (does not append) existing content.
tsocmd "ALLOC DATASET('${userid}.BOZ.NEWCERT') MOD CATALOG \
  RECFM(V,B) LRECL(1028) BLKSIZE(27998) TRACKS SPACE(5,5)"

# dcp for binary copy (cp "//dataset" doesn't work reliably for DER)
$DCP -B "$TMPDIR/boz-new.der" "${userid}.BOZ.NEWCERT"

tsocmd "RACDCERT ADD('${userid}.BOZ.NEWCERT') \
  ID($userid) \
  WITHLABEL('$label') \
  FORMAT(CERTDER) \
  TRUST"

tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH"

print_success "Certificate generated successfully."
print_info "  Cert label : $label"
print_info "  Private key: stays in RACF - never written to USS filesystem"
print_info "  Validity   : capped at CAB Forum limit for today's date (200/100/47 days)"
print_info "  SANs       : IP=$ipaddr  DNS=$dnsname"
print_info "  EKU        : TLS Web Server Authentication"
print_info "  Caller (addcert.sh) will connect cert to keyring $ring as DEFAULT."
