#!/bin/sh
# =============================================================================
# Script  : gencert-eku.sh
# Summary : Generate a TLS server certificate with EKU serverAuth (OID
#           1.3.6.1.5.5.7.3.1) signed by VSICA, for Safari/Apple ATS
#           compliance.  RACDCERT GENCERT cannot add EKU.
#
# Approach (CSR round-trip — private key stays in RACF):
#   1. Delete any existing placeholder cert from RACF.
#   2. RACDCERT GENCERT REQONLY  — RACF generates the keypair and outputs
#      a PKCS#10 CSR.  The private key never leaves RACF.
#   3. Export the CSR to USS (FORMAT(PKCS10DER) / FORMAT(CERTDER)).
#   4. Bouncy Castle (bcprov) reads the CSR, signs it with VSICA adding
#      EKU serverAuth + SANs + 397-day validity.  Outputs the signed cert
#      as a DER file on USS.
#   5. RACDCERT IMPORT the signed cert — RACF matches it to the private key
#      it already holds.
#   6. Connect the cert to BOZRING as DEFAULT.
#   7. Liberty uses safkeyring://IBMUSER/BOZRING — no file-based keystore.
#
# Called by addcert.sh after the keyring scaffold is in place.
# =============================================================================

# Source setenv.sh to get SANDBOX_DIR when called standalone
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../config/setenv.sh" 2>/dev/null || true

set -e

userid=IBMUSER
ring=BOZRING
label='BoZ'

# Resolve Java
if [ -n "${JAVA_HOME:-}" ]; then
  JAVA="$JAVA_HOME/bin/java"
  JAVAC="$JAVA_HOME/bin/javac"
else
  JAVA=$(command -v java 2>/dev/null) || { echo "[gencert-eku] FATAL: java not found" >&2; exit 1; }
  JAVAC=$(command -v javac 2>/dev/null) || { echo "[gencert-eku] FATAL: javac not found" >&2; exit 1; }
fi

# Resolve Python
if [ -n "${PYTHON_HOME:-}" ]; then
  PYTHON="$PYTHON_HOME/bin/python3"
else
  PYTHON=$(command -v python3 2>/dev/null) || { echo "[gencert-eku] FATAL: python3 not found" >&2; exit 1; }
fi

# Resolve Bouncy Castle JAR
BCJAR=$(ls "${SANDBOX_DIR:-/usr/local/sandboxes/bank-of-z}/tools"/*/lib/plugins/bcprov-*.jar 2>/dev/null | head -1)
if [ -z "$BCJAR" ]; then
  echo "[gencert-eku] FATAL: bcprov-*.jar not found under \${SANDBOX_DIR}/tools" >&2
  exit 1
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
echo "[gencert-eku] Private key will remain in RACF keyring (CSR round-trip approach)."

# Random CA export password via Python
CA_PASS=$($PYTHON -c "import secrets; print(secrets.token_urlsafe(18))")

# Race-safe temp dir
TMPDIR=/tmp/boz-cert-$$
mkdir -m 700 -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"; tsocmd "DELETE (\047${userid}.BOZ.CAKEY\047)" >/dev/null 2>&1; tsocmd "DELETE (\047${userid}.BOZ.CSR\047)" >/dev/null 2>&1; tsocmd "DELETE (\047${userid}.BOZ.NEWCERT\047)" >/dev/null 2>&1' EXIT

# -----------------------------------------------------------------------
# 1. Remove old placeholder cert so GENCERT REQONLY can create a fresh one.
#    Errors suppressed — cert may not exist yet.
# -----------------------------------------------------------------------
echo "[gencert-eku] Removing old placeholder cert from keyring..."
tsocmd "RACDCERT ID($userid) \
  REMOVE(LABEL('$label') RING($ring))" >/dev/null 2>&1 || true
tsocmd "RACDCERT ID($userid) DELETE(LABEL('$label'))" >/dev/null 2>&1 || true
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH" >/dev/null 2>&1 || true

# -----------------------------------------------------------------------
# 2. Generate keypair in RACF and output a CSR (private key stays in RACF).
# -----------------------------------------------------------------------
echo "[gencert-eku] Generating keypair in RACF (GENCERT REQONLY)..."
tsocmd "RACDCERT GENCERT \
  ID($userid) \
  SUBJECTSDN(CN('Bank of Z') O('IBM') OU('IBM BoZ') C('US')) \
  ALTNAME(IP($ipaddr) DOMAIN('$dnsname')) \
  WITHLABEL('$label') \
  SIZE(2048) \
  KEYUSAGE(HANDSHAKE DATAENCRYPT) \
  REQONLY \
  DSN('${userid}.BOZ.CSR') FORMAT(PKCS10DER)"

# Copy CSR binary from RACF dataset to USS temp dir
cp "//'${userid}.BOZ.CSR'" "$TMPDIR/boz.csr"

# -----------------------------------------------------------------------
# 3. Export VSICA cert + key for signing
# -----------------------------------------------------------------------
echo "[gencert-eku] Exporting VSICA CA for signing..."
tsocmd "RACDCERT EXPORT(LABEL('VSICA')) CERTAUTH \
  DSN('${userid}.BOZ.CAKEY') FORMAT(PKCS12DER) PASSWORD('${CA_PASS}')"
cp "//'${userid}.BOZ.CAKEY'" "$TMPDIR/vsica.p12"

# -----------------------------------------------------------------------
# 4. Write SignCsr.java via Python (avoids _BPXK_AUTOCVT EBCDIC corruption)
# -----------------------------------------------------------------------
$PYTHON - "$TMPDIR/SignCsr.java" << 'PYEOF'
import sys
src = r"""
// Signs a PKCS#10 CSR with VSICA, adding EKU serverAuth + SANs.
// Uses only bcprov (no bcpkix) via the low-level BC ASN.1 API.
import org.bouncycastle.asn1.ASN1EncodableVector;
import org.bouncycastle.asn1.ASN1Integer;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.ASN1Sequence;
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
import org.bouncycastle.asn1.pkcs.CertificationRequest;
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
import java.util.Date;

public class SignCsr {
    static final ASN1ObjectIdentifier EKU_SERVER_AUTH =
        new ASN1ObjectIdentifier("1.3.6.1.5.5.7.3.1");
    static final ASN1ObjectIdentifier SHA256_WITH_RSA =
        new ASN1ObjectIdentifier("1.2.840.113549.1.1.11");
    // Apple ATS maximum: 397 days
    static final long MAX_VALIDITY_MS = 397L * 24 * 60 * 60 * 1000;

    public static void main(String[] args) throws Exception {
        String csrPath  = args[0];
        String caPath   = args[1];  String caPass  = args[2];
        String certOut  = args[3];
        String ip       = args[4];  String dns     = args[5];
        String notAfter = args[6];

        Security.addProvider(new BouncyCastleProvider());

        // Load CA keystore (VSICA)
        KeyStore caKs = KeyStore.getInstance("PKCS12");
        try (InputStream in = new FileInputStream(caPath)) {
            caKs.load(in, caPass.toCharArray());
        }
        String caAlias = caKs.aliases().nextElement();
        PrivateKey caKey  = (PrivateKey) caKs.getKey(caAlias, caPass.toCharArray());
        X509Certificate caCert = (X509Certificate) caKs.getCertificate(caAlias);

        // Parse CSR to extract subject and public key
        byte[] csrBytes = Files.readAllBytes(Paths.get(csrPath));
        CertificationRequest csr = CertificationRequest.getInstance(
            ASN1Sequence.getInstance(csrBytes));
        SubjectPublicKeyInfo spki = csr.getCertificationRequestInfo().getSubjectPublicKeyInfo();
        X500Name subject = X500Name.getInstance(
            csr.getCertificationRequestInfo().getSubject());

        // Validity: 5-minute clock skew tolerance; cap at 397 days
        Date notBefore = new Date(System.currentTimeMillis() - 5 * 60 * 1000);
        Date requestedEnd = Date.from(
            LocalDate.parse(notAfter).atStartOfDay(ZoneOffset.UTC).toInstant());
        Date cappedEnd = new Date(notBefore.getTime() + MAX_VALIDITY_MS);
        Date notAfterDate = requestedEnd.before(cappedEnd) ? requestedEnd : cappedEnd;
        System.out.println("Validity: " + notBefore + " -> " + notAfterDate);

        X500Name issuer = X500Name.getInstance(
            caCert.getSubjectX500Principal().getEncoded());

        // Extensions: SANs, Key Usage, EKU serverAuth
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

        BigInteger serial = new BigInteger(159, new SecureRandom());

        AlgorithmIdentifier sigAlg =
            new AlgorithmIdentifier(SHA256_WITH_RSA, DERNull.INSTANCE);
        V3TBSCertificateGenerator tbsGen = new V3TBSCertificateGenerator();
        tbsGen.setSerialNumber(new ASN1Integer(serial));
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
        v.add(tbs);
        v.add(sigAlg);
        v.add(new DERBitString(sigBytes));
        byte[] certDer = new DERSequence(v).getEncoded();

        // Verify the cert chains to the CA before writing
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        X509Certificate cert = (X509Certificate) cf.generateCertificate(
            new ByteArrayInputStream(certDer));
        cert.verify(caCert.getPublicKey());
        System.out.println("Signature verified against VSICA.");

        // Write signed cert as DER
        try (FileOutputStream fos = new FileOutputStream(certOut)) {
            fos.write(certDer);
        }
        System.out.println("Signed cert (DER) written to: " + certOut);
    }
}
"""
with open(sys.argv[1], 'wb') as f:
    f.write(src.encode('iso-8859-1'))
PYEOF

echo "[gencert-eku] Compiling SignCsr.java..."
$JAVAC -cp "$BCJAR" "$TMPDIR/SignCsr.java" -d "$TMPDIR"

# -----------------------------------------------------------------------
# 5. Run it — produces a DER-encoded signed certificate
# -----------------------------------------------------------------------
echo "[gencert-eku] Signing CSR with VSICA, adding EKU serverAuth..."
$JAVA -cp "$TMPDIR:$BCJAR" SignCsr \
  "$TMPDIR/boz.csr" \
  "$TMPDIR/vsica.p12" "$CA_PASS" \
  "$TMPDIR/boz-signed.der" \
  "$ipaddr" "$dnsname" "$expire"

test -s "$TMPDIR/boz-signed.der" || {
  echo "[gencert-eku] FATAL: signed cert not produced" >&2; exit 1; }

# -----------------------------------------------------------------------
# 6. Import the signed cert back into RACF.
#    RACF matches it to the private key it already holds from GENCERT REQONLY.
#    The private key never left RACF at any point.
# -----------------------------------------------------------------------
echo "[gencert-eku] Importing signed cert into RACF..."
# Copy signed cert DER to a RACF dataset (binary — no EBCDIC conversion)
cp "$TMPDIR/boz-signed.der" "//'${userid}.BOZ.NEWCERT'"

tsocmd "RACDCERT IMPORT('${userid}.BOZ.NEWCERT') \
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
echo "[gencert-eku]   Validity   : 397 days from now (Safari-compliant)"
echo "[gencert-eku]   SANs       : IP=$ipaddr  DNS=$dnsname"
echo "[gencert-eku]   EKU        : TLS Web Server Authentication"
echo "[gencert-eku]   Liberty    : uses safkeyring://IBMUSER/$ring (JCERACFKS)"
echo "[gencert-eku] Restart BAQBANKZ to pick up the new certificate."
