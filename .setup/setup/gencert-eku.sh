#!/bin/sh
# =============================================================================
# Script  : gencert-eku.sh
# Summary : Generate a TLS server certificate with EKU serverAuth (OID
#           1.3.6.1.5.5.7.3.1) signed by VSICA, with the private key
#           remaining in the RACF keyring at all times.
#
# Approach (re-sign existing RACF cert — private key never leaves RACF):
#   1. RACDCERT GENCERT SIGNWITH(CERTAUTH LABEL('VSICA')) — RACF generates
#      keypair and a VSICA-signed cert.  Private key stays in RACF.
#   2. dcp export the cert as CERTB64 (PEM) to USS.
#   3. Bouncy Castle reads the public key from the PEM, builds a new
#      TBSCertificate with EKU serverAuth + SANs + 397-day validity, and
#      re-signs it with VSICA's key (exported as PKCS12DER, deleted after).
#   4. dcp the new DER cert back to a RACF dataset.
#   5. RACDCERT ADD FORMAT(CERTDER) — RACF matches the new cert to the
#      private key it already holds (same public key).
#   6. Connect cert to BOZRING as DEFAULT.
#   7. Liberty uses safkeyring://IBMUSER/BOZRING (JCERACFKS).
#
# Called by addcert.sh after the keyring scaffold is in place.
# =============================================================================

# Derive SANDBOX_DIR from script location when not already in environment.
# (setenv.sh requires bash; this script is sh — do not source it here.)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${SANDBOX_DIR:-}" ]; then
  SANDBOX_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  export SANDBOX_DIR
fi

set -e

userid=IBMUSER
ring=BOZRING
label='BoZ'

# -----------------------------------------------------------------------
# Resolve tools — fall back to known fixed paths when env vars not set.
# -----------------------------------------------------------------------
if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME=/usr/local/sandboxes/tools/J21.0_64
  export JAVA_HOME
fi
JAVA="$JAVA_HOME/bin/java"
JAVAC="$JAVA_HOME/bin/javac"
if [ ! -x "$JAVA" ]; then
  echo "[gencert-eku] FATAL: java not found at $JAVA" >&2; exit 1
fi

if [ -n "${PYTHON_HOME:-}" ] && [ -x "$PYTHON_HOME/bin/python3" ]; then
  PYTHON="$PYTHON_HOME/bin/python3"
elif [ -x /usr/lpp/IBM/cyp/v3r14/pyz/bin/python3 ]; then
  PYTHON=/usr/lpp/IBM/cyp/v3r14/pyz/bin/python3
else
  PYTHON=$(command -v python3 2>/dev/null) || { echo "[gencert-eku] FATAL: python3 not found" >&2; exit 1; }
fi

# Ensure ZOAU tools (dcp, tsocmd, etc.) are on PATH
if [ -n "${ZOAU_HOME:-}" ] && [ -x "$ZOAU_HOME/bin/dcp" ]; then
  export PATH="$ZOAU_HOME/bin:$PATH"
elif [ -x /usr/lpp/IBM/zoautil/bin/dcp ]; then
  export PATH="/usr/lpp/IBM/zoautil/bin:$PATH"
fi
DCP=$(command -v dcp 2>/dev/null) || { echo "[gencert-eku] FATAL: dcp (ZOAU) not found on PATH" >&2; exit 1; }

_TOOLS_DIR="${SANDBOX_DIR}/../tools"
BCJAR=$(ls "$_TOOLS_DIR"/*/lib/plugins/bcprov-*.jar 2>/dev/null | head -1)
if [ -z "$BCJAR" ]; then
  echo "[gencert-eku] FATAL: bcprov-*.jar not found under $_TOOLS_DIR" >&2; exit 1
fi

# -----------------------------------------------------------------------
# Guard: verify IP and DNS can be determined
# -----------------------------------------------------------------------
ipaddr=$(netstat -h 2>/dev/null | awk '/ OSA/ {print $1}')
test "$ipaddr" = "IntfName:" && ipaddr=$(netstat -h 2>/dev/null \
  | awk '/ OSA/ {f=1; next} f {print $2; exit}')
dnsname=$(hostname 2>/dev/null)

if [ -z "$ipaddr" ] || [ -z "$dnsname" ]; then
  echo "[gencert-eku] FATAL: could not determine IP ($ipaddr) or DNS ($dnsname)" >&2
  exit 1
fi

expire=$(tsocmd "RACDCERT CERTAUTH LIST(LABEL('VSICA'))" \
  | awk '/End Date:/ {gsub("/","-",$3); print $3}')

echo "[gencert-eku] IP=$ipaddr  DNS=$dnsname  VSICA expire=$expire"
echo "[gencert-eku] Private key stays in RACF keyring throughout."

# Random passwords via Python
CA_PASS=$($PYTHON -c "import secrets; print(secrets.token_urlsafe(18))")

# Race-safe temp dir
TMPDIR=/tmp/boz-cert-$$
mkdir -m 700 -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"
  tsocmd "DELETE (\047${userid}.BOZ.CAKEY\047)" >/dev/null 2>&1 || true
  tsocmd "DELETE (\047${userid}.BOZ.CERTB64\047)" >/dev/null 2>&1 || true
  tsocmd "DELETE (\047${userid}.BOZ.NEWCERT\047)" >/dev/null 2>&1 || true' EXIT

# -----------------------------------------------------------------------
# 1. Remove any existing cert so GENCERT can create a fresh one.
# -----------------------------------------------------------------------
echo "[gencert-eku] Removing old cert from keyring..."
tsocmd "RACDCERT ID($userid) \
  REMOVE(LABEL('$label') RING($ring))" >/dev/null 2>&1 || true
tsocmd "RACDCERT ID($userid) DELETE(LABEL('$label'))" >/dev/null 2>&1 || true
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH" >/dev/null 2>&1 || true

# -----------------------------------------------------------------------
# 2. Generate keypair + cert in RACF, signed by VSICA.
#    Private key is generated inside RACF and never leaves.
# -----------------------------------------------------------------------
echo "[gencert-eku] Generating keypair in RACF (SIGNWITH VSICA)..."
tsocmd "RACDCERT GENCERT \
  ID($userid) \
  SUBJECTSDN(CN('Bank of Z') O('IBM') OU('IBM BoZ') C('US')) \
  SIGNWITH(CERTAUTH LABEL('VSICA')) \
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
#    on this RACF version — dcp handles the dataset-to-USS copy correctly.
# -----------------------------------------------------------------------
echo "[gencert-eku] Exporting cert as PEM for re-signing..."
tsocmd "RACDCERT EXPORT(LABEL('$label')) ID($userid) \
  DSN('${userid}.BOZ.CERTB64') FORMAT(CERTB64)"
$DCP "${userid}.BOZ.CERTB64" "$TMPDIR/boz-orig.pem"
# Java (ResignCert) handles Cp1047/EBCDIC decoding directly — no conversion needed here.

# -----------------------------------------------------------------------
# 4. Export VSICA private key (PKCS12DER) so Bouncy Castle can re-sign.
#    Dataset deleted in EXIT trap.
# -----------------------------------------------------------------------
echo "[gencert-eku] Exporting VSICA CA for re-signing..."
tsocmd "RACDCERT EXPORT(LABEL('VSICA')) CERTAUTH \
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
    static final long MAX_VALIDITY_MS = 397L * 24 * 60 * 60 * 1000;

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
        // from the RACF dataset — try Cp1047 first, fall back to ISO-8859-1.
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

        // Validity: 5-min skew tolerance; cap at 397 days (Apple ATS)
        Date notBefore    = new Date(System.currentTimeMillis() - 5 * 60 * 1000);
        Date requestedEnd = Date.from(
            LocalDate.parse(notAfter).atStartOfDay(ZoneOffset.UTC).toInstant());
        Date cappedEnd    = new Date(notBefore.getTime() + MAX_VALIDITY_MS);
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

echo "[gencert-eku] Compiling ResignCert.java..."
$JAVAC -cp "$BCJAR" "$TMPDIR/ResignCert.java" -d "$TMPDIR"

# -----------------------------------------------------------------------
# 6. Run ResignCert — produces a DER cert with EKU, signed by VSICA,
#    containing the SAME public key as the RACF-held private key.
# -----------------------------------------------------------------------
echo "[gencert-eku] Re-signing cert with EKU serverAuth..."
$JAVA -cp "$TMPDIR:$BCJAR" ResignCert \
  "$TMPDIR/boz-orig.pem" \
  "$TMPDIR/vsica.p12" "$CA_PASS" \
  "$TMPDIR/boz-new.der" \
  "$ipaddr" "$dnsname" "$expire"

test -s "$TMPDIR/boz-new.der" || {
  echo "[gencert-eku] FATAL: boz-new.der not produced" >&2; exit 1; }

# -----------------------------------------------------------------------
# 7. Copy new DER cert to RACF dataset and IMPORT it.
#    RACF will match it to the private key already held for label '$label'
#    because they share the same public key.
# -----------------------------------------------------------------------
echo "[gencert-eku] Importing re-signed cert into RACF..."
# Pre-allocate with correct DCB for binary DER data
tsocmd "DELETE ('${userid}.BOZ.NEWCERT')" >/dev/null 2>&1 || true
tsocmd "ALLOC DATASET('${userid}.BOZ.NEWCERT') NEW CATALOG \
  RECFM(V,B) LRECL(1028) BLKSIZE(27998) TRACKS SPACE(5,5)"

# dcp for binary copy (cp "//dataset" doesn't work reliably for DER)
$DCP -B "$TMPDIR/boz-new.der" "${userid}.BOZ.NEWCERT"

tsocmd "RACDCERT ADD('${userid}.BOZ.NEWCERT') \
  ID($userid) \
  WITHLABEL('$label') \
  FORMAT(CERTDER) \
  TRUST"

tsocmd "RACDCERT ID($userid) \
  CONNECT(LABEL('$label') RING($ring) DEFAULT)"

tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH"

echo "[gencert-eku] Done."
echo "[gencert-eku]   Cert label : $label  (in keyring IBMUSER/$ring)"
echo "[gencert-eku]   Private key: stays in RACF — never written to USS filesystem"
echo "[gencert-eku]   Validity   : 397 days (Safari/Apple ATS compliant)"
echo "[gencert-eku]   SANs       : IP=$ipaddr  DNS=$dnsname"
echo "[gencert-eku]   EKU        : TLS Web Server Authentication"
echo "[gencert-eku]   Liberty    : uses safkeyring://IBMUSER/$ring (JCERACFKS)"
echo "[gencert-eku] Restart BAQBANKZ to pick up the new certificate."
