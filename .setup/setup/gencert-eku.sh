#!/bin/sh
# =============================================================================
# Script  : gencert-eku.sh
# Summary : Generate a TLS server certificate with EKU serverAuth (OID
#           1.3.6.1.5.5.7.3.1) signed by VSICA, for Safari/Apple ATS
#           compliance.  RACDCERT GENCERT cannot add EKU, so this script
#           uses Bouncy Castle (already on image via Gradle) to build the
#           cert and writes it as a file-based PKCS12 keystore for Liberty.
#
# NOTE: Liberty uses a file-based PKCS12 keystore, not the RACF keyring.
#       Access control is filesystem permissions (chmod 600), not RDATALIB.
#       This is a deliberate trade-off: RACDCERT GENCERT cannot add EKU
#       serverAuth, which Safari requires since macOS 10.15 / iOS 13.
#
# Called by addcert.sh after the basic keyring scaffold is in place.
# =============================================================================

# Derive SANDBOX_DIR from script location when not already in environment.
# (setenv.sh requires bash; this script is sh — do not source it here.)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${SANDBOX_DIR:-}" ]; then
  # .setup/setup → .setup → Bank-of-Z → sandbox parent
  SANDBOX_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  export SANDBOX_DIR
fi

set -e

userid=IBMUSER

# -----------------------------------------------------------------------
# Resolve tools — fall back to known fixed paths when env vars not set.
# Java: JAVA_HOME exported by setenv.sh; hardcoded fallback for standalone.
# Python: PYTHON_HOME from setenv.sh; known fixed path as fallback.
# bcprov JAR: tools/ is one level above SANDBOX_DIR (bank-of-z).
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

_TOOLS_DIR="${SANDBOX_DIR}/../tools"
BCJAR=$(ls "$_TOOLS_DIR"/*/lib/plugins/bcprov-*.jar 2>/dev/null | head -1)
if [ -z "$BCJAR" ]; then
  echo "[gencert-eku] FATAL: bcprov-*.jar not found under $_TOOLS_DIR" >&2
  exit 1
fi

# -----------------------------------------------------------------------
# Guard: verify IP and DNS can be determined before doing anything
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
echo "[gencert-eku] NOTE: Liberty will use file-based PKCS12, not the RACF keyring."
echo "[gencert-eku]       Access control: chmod 600, not RDATALIB."

# -----------------------------------------------------------------------
# Randomise passwords via Python — tr/dev/urandom not reliable on z/OS USS
# -----------------------------------------------------------------------
CA_PASS=$($PYTHON -c "import secrets; print(secrets.token_urlsafe(18))")
KS_PASS=$($PYTHON -c "import secrets; print(secrets.token_urlsafe(18))")

# -----------------------------------------------------------------------
# Race-safe temp dir with restricted permissions so CA key is not world-readable
# (mktemp not available on z/OS USS — use mkdir -m 700 with PID-based name)
# -----------------------------------------------------------------------
TMPDIR=/tmp/boz-cert-$$
mkdir -m 700 -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"; tsocmd "DELETE (\047${userid}.BOZ.CAKEY\047)" >/dev/null 2>&1 || true' EXIT

# -----------------------------------------------------------------------
# 1. Export VSICA cert + private key to a temp PKCS12 dataset.
#    The dataset is deleted in the EXIT trap above.
# -----------------------------------------------------------------------
echo "[gencert-eku] Exporting VSICA to temp PKCS12..."
tsocmd "RACDCERT EXPORT(LABEL('VSICA')) CERTAUTH \
  DSN('${userid}.BOZ.CAKEY') FORMAT(PKCS12DER) PASSWORD('${CA_PASS}')"

# Binary copy — no EBCDIC conversion
cp "//'${userid}.BOZ.CAKEY'" "$TMPDIR/vsica.p12"

# -----------------------------------------------------------------------
# 2. Write GenCert.java via Python — avoids _BPXK_AUTOCVT EBCDIC corruption
# -----------------------------------------------------------------------
$PYTHON - "$TMPDIR/GenCert.java" << 'PYEOF'
import sys
src = r"""
// Uses only bcprov (no bcpkix) via the low-level BC ASN.1 API.
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
import java.io.OutputStream;
import java.math.BigInteger;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.Security;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.RSAKeyGenParameterSpec;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;

public class GenCert {
    static final ASN1ObjectIdentifier EKU_SERVER_AUTH =
        new ASN1ObjectIdentifier("1.3.6.1.5.5.7.3.1");
    static final ASN1ObjectIdentifier SHA256_WITH_RSA =
        new ASN1ObjectIdentifier("1.2.840.113549.1.1.11");
    // Apple ATS maximum validity: 397 days (since 2020-09-01)
    static final long MAX_VALIDITY_MS = 397L * 24 * 60 * 60 * 1000;

    public static void main(String[] args) throws Exception {
        String caPath   = args[0];  String caPass  = args[1];
        String outPath  = args[2];  String outPass = args[3];
        String ip       = args[4];  String dns     = args[5];
        String notAfter = args[6];

        Security.addProvider(new BouncyCastleProvider());

        KeyStore caKs = KeyStore.getInstance("PKCS12");
        try (InputStream in = new FileInputStream(caPath)) {
            caKs.load(in, caPass.toCharArray());
        }
        String caAlias = caKs.aliases().nextElement();
        PrivateKey caKey  = (PrivateKey) caKs.getKey(caAlias, caPass.toCharArray());
        X509Certificate caCert = (X509Certificate) caKs.getCertificate(caAlias);

        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA", "BC");
        kpg.initialize(new RSAKeyGenParameterSpec(2048, RSAKeyGenParameterSpec.F4));
        KeyPair kp = kpg.generateKeyPair();

        // 5-minute clock skew tolerance so slightly-behind clients don't fail
        Date notBefore    = new Date(System.currentTimeMillis() - 5 * 60 * 1000);

        // Cap validity at 397 days — Apple ATS / Safari hard limit
        Date requestedEnd = Date.from(
            LocalDate.parse(notAfter).atStartOfDay(ZoneOffset.UTC).toInstant());
        Date cappedEnd    = new Date(notBefore.getTime() + MAX_VALIDITY_MS);
        Date notAfterDate = requestedEnd.before(cappedEnd) ? requestedEnd : cappedEnd;
        System.out.println("Validity: " + notBefore + " -> " + notAfterDate);

        X500Name subject = new X500Name("CN=Bank of Z,OU=IBM BoZ,O=IBM,C=US");
        // Build issuer from DER bytes to match PKCS12 chain validation exactly
        X500Name issuer = X500Name.getInstance(
            caCert.getSubjectX500Principal().getEncoded());
        SubjectPublicKeyInfo spki = SubjectPublicKeyInfo.getInstance(
            kp.getPublic().getEncoded());

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

        // Random 20-byte serial — RFC 5280 recommends >= 64 bits of entropy
        BigInteger serial = new BigInteger(159, new SecureRandom());

        AlgorithmIdentifier sigAlg = new AlgorithmIdentifier(SHA256_WITH_RSA, DERNull.INSTANCE);
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

        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        X509Certificate cert = (X509Certificate) cf.generateCertificate(
            new ByteArrayInputStream(certDer));
        cert.verify(caCert.getPublicKey());

        KeyStore out = KeyStore.getInstance("PKCS12");
        out.load(null, null);
        out.setKeyEntry("boz", kp.getPrivate(), outPass.toCharArray(),
            new java.security.cert.Certificate[]{ cert, caCert });
        try (OutputStream os = new FileOutputStream(outPath)) {
            out.store(os, outPass.toCharArray());
        }
        System.out.println("Generated cert with EKU serverAuth: " + outPath);
    }
}
"""
with open(sys.argv[1], 'wb') as f:
    f.write(src.encode('iso-8859-1'))
PYEOF

echo "[gencert-eku] Compiling GenCert.java..."
$JAVAC -cp "$BCJAR" "$TMPDIR/GenCert.java" -d "$TMPDIR"

# -----------------------------------------------------------------------
# 3. Run it — produces a PKCS12 with the new server cert + key
# -----------------------------------------------------------------------
echo "[gencert-eku] Generating cert with EKU serverAuth..."
$JAVA -cp "$TMPDIR:$BCJAR" GenCert \
  "$TMPDIR/vsica.p12" "$CA_PASS" \
  "$TMPDIR/boz-server.p12" "$KS_PASS" \
  "$ipaddr" "$dnsname" "$expire"

# Verify the PKCS12 was actually written before proceeding
test -s "$TMPDIR/boz-server.p12" || {
  echo "[gencert-eku] FATAL: boz-server.p12 not produced" >&2; exit 1; }

# -----------------------------------------------------------------------
# 4. Install as file-based keystore for Liberty.
#    The keystore password is written into tls.xml so Liberty can open it.
#    Liberty obfuscates it in memory; the file is chmod 600.
# -----------------------------------------------------------------------
echo "[gencert-eku] Installing PKCS12 keystore for Liberty..."

KEYSTORE_DIR="/u/$(echo $userid | tr '[:upper:]' '[:lower:]')/boz-certs"
mkdir -p "$KEYSTORE_DIR"
cp "$TMPDIR/boz-server.p12" "$KEYSTORE_DIR/boz-server.p12"
chmod 600 "$KEYSTORE_DIR/boz-server.p12"

OVERRIDES_DIR="${SANDBOX_DIR}/zosconnect-server/servers/bankzServer/configDropins/overrides"
TLS_DEST="${OVERRIDES_DIR}/tls.xml"

# Write tls.xml with the per-run keystore password via Python (avoids AUTOCVT)
$PYTHON - "$TLS_DEST" "$KEYSTORE_DIR/boz-server.p12" "$KS_PASS" << 'TLSEOF'
import sys
dest, p12path, ks_pass = sys.argv[1], sys.argv[2], sys.argv[3]
content = '''<?xml version="1.0" encoding="UTF-8"?>
<server>
    <!--
      TLS config: file-based PKCS12 keystore with EKU serverAuth (Safari-compatible).
      NOTE: private key is stored on USS filesystem, not in the RACF keyring.
      Access control: chmod 600 on the .p12 file.
      The keystore password is regenerated on each setup-remote run.
    -->
    <ssl id="defaultSSLConfig" keyStoreRef="defaultKeyStore" trustStoreRef="defaultKeyStore"/>
    <keyStore id="defaultKeyStore"
              location="{p12}"
              type="PKCS12"
              password="{pw}"/>
</server>
'''.format(p12=p12path, pw=ks_pass)
with open(dest, 'wb') as f:
    f.write(content.encode('iso-8859-1'))
TLSEOF
chtag -t -c ISO8859-1 "$TLS_DEST"

# Verify the dropin was written (non-empty)
test -s "$TLS_DEST" || {
  echo "[gencert-eku] FATAL: tls.xml not written to $TLS_DEST" >&2; exit 1; }

echo "[gencert-eku] Done."
echo "[gencert-eku]   Keystore  : $KEYSTORE_DIR/boz-server.p12"
echo "[gencert-eku]   TLS dropin: $TLS_DEST"
echo "[gencert-eku]   Validity  : 397 days from now (Safari-compliant)"
echo "[gencert-eku]   SANs      : IP=$ipaddr  DNS=$dnsname"
echo "[gencert-eku]   EKU       : TLS Web Server Authentication"
echo "[gencert-eku] Restart BAQBANKZ to pick up the new certificate."
