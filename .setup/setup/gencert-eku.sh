#!/bin/sh
# =============================================================================
# Script  : gencert-eku.sh
# Source setenv.sh to get SANDBOX_DIR and other environment variables.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../config/setenv.sh" 2>/dev/null || true
# =============================================================================
# Script  : gencert-eku.sh (continued)
# Summary : Generate a TLS server certificate with EKU serverAuth (OID
#           1.3.6.1.5.5.7.3.1) signed by VSICA, for Safari/Apple ATS
#           compliance.  RACDCERT GENCERT cannot add EKU, so this script
#           uses Bouncy Castle (already on image via Gradle) to:
#             1. Export VSICA cert+key from RACF to a temp PKCS12 dataset
#             2. Run a Java program that generates a new keypair, builds a
#                cert with the right SANs and EKU, signs it with VSICA
#             3. RACDCERT IMPORT the result as label 'BoZ' into BOZRING
#             4. Delete all temp PKCS12 datasets immediately
#
# Called by addcert.sh after the basic keyring scaffold is in place.
# =============================================================================

set -e

userid=IBMUSER
ring=BOZRING
label='BoZ'
JAVA=/usr/lpp/java/java21/J21.0_64/bin/java
JAVAC=/usr/lpp/java/java21/J21.0_64/bin/javac
BCJAR=/usr/local/sandboxes/tools/gradle-9.5.1/lib/plugins/bcprov-jdk18on-1.84.jar
TMPDIR=/tmp/boz-cert-$$

# system variables
ipaddr=$(netstat -h 2>/dev/null | awk '/ OSA/ {print $1}')
test "$ipaddr" = "IntfName:" && ipaddr=$(netstat -h 2>/dev/null \
  | awk '/ OSA/ {f=1; next} f {print $2; exit}')
dnsname=$(hostname 2>/dev/null)
expire=$(tsocmd "RACDCERT CERTAUTH LIST(LABEL('VSICA'))" \
  | awk '/End Date:/ {gsub("/","-",$3); print $3}')

echo "[gencert-eku] IP=$ipaddr  DNS=$dnsname  expire=$expire"

mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"; tsocmd "DELETE (\047${userid}.BOZ.CAKEY\047)" >/dev/null 2>&1; tsocmd "DELETE (\047${userid}.BOZ.NEWCERT\047)" >/dev/null 2>&1' EXIT

# -----------------------------------------------------------------------
# 1. Export VSICA cert + private key to a PKCS12 dataset so Bouncy Castle
#    can sign with it.  The dataset is deleted in the EXIT trap above.
# -----------------------------------------------------------------------
echo "[gencert-eku] Exporting VSICA to temp PKCS12..."
tsocmd "RACDCERT EXPORT(LABEL('VSICA')) CERTAUTH \
  DSN('${userid}.BOZ.CAKEY') FORMAT(PKCS12DER) PASSWORD('bozca')"

# Copy the binary PKCS12 dataset to USS (binary copy — no EBCDIC conversion)
cp "//'${userid}.BOZ.CAKEY'" "$TMPDIR/vsica.p12"

# -----------------------------------------------------------------------
# 2. Write GenCert.java via Python — avoids _BPXK_AUTOCVT EBCDIC conversion
#    that would corrupt a shell heredoc write on z/OS USS.
# -----------------------------------------------------------------------
PYTHON=/usr/lpp/IBM/cyp/v3r14/pyz/bin/python3.14
$PYTHON - "$TMPDIR/GenCert.java" << 'PYEOF'
import sys
src = r"""
// Uses only bcprov (no bcpkix) via the low-level BC ASN.1 API.
// Explicit single-class imports avoid the java.security.cert.Extension ambiguity.
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
import org.bouncycastle.asn1.x509.KeyPurposeId;
import org.bouncycastle.asn1.x509.ExtensionsGenerator;
import org.bouncycastle.asn1.x509.GeneralName;
import org.bouncycastle.asn1.x509.GeneralNames;
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

        Date notBefore    = new Date();
        Date notAfterDate = Date.from(
            LocalDate.parse(notAfter).atStartOfDay(ZoneOffset.UTC).toInstant());

        X500Name subject = new X500Name("CN=Bank of Z,OU=IBM BoZ,O=IBM,C=US");
        // Build issuer directly from the CA cert's DER-encoded subject to ensure
        // the chain validation in PKCS12KeyStore matches exactly.
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

        AlgorithmIdentifier sigAlg = new AlgorithmIdentifier(SHA256_WITH_RSA, DERNull.INSTANCE);
        V3TBSCertificateGenerator tbsGen = new V3TBSCertificateGenerator();
        tbsGen.setSerialNumber(new ASN1Integer(BigInteger.valueOf(System.currentTimeMillis())));
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
  "$TMPDIR/vsica.p12" "bozca" \
  "$TMPDIR/boz-server.p12" "bozserver" \
  "$ipaddr" "$dnsname" "$expire"

# -----------------------------------------------------------------------
# 4. Install the PKCS12 as a file-based keystore for Liberty.
#    RACF IMPORT doesn't accept standard PKCS12 format — Liberty can use
#    a file-based keystore directly, which avoids the RACF import entirely.
# -----------------------------------------------------------------------
echo "[gencert-eku] Installing PKCS12 keystore for Liberty..."

KEYSTORE_DIR="/u/$(echo $userid | tr '[:upper:]' '[:lower:]')/boz-certs"
mkdir -p "$KEYSTORE_DIR"
cp "$TMPDIR/boz-server.p12" "$KEYSTORE_DIR/boz-server.p12"
chmod 600 "$KEYSTORE_DIR/boz-server.p12"

# Update Liberty TLS config to point at the file-based keystore instead of
# the RACF keyring.  Overwrites the tls.xml dropin written by
# setup-zosconnect-server.sh.
OVERRIDES_DIR="${SANDBOX_DIR}/zosconnect-server/servers/bankzServer/configDropins/overrides"
PYTHON=/usr/lpp/IBM/cyp/v3r14/pyz/bin/python3.14
TLS_DEST="${OVERRIDES_DIR}/tls.xml"
$PYTHON - "$TLS_DEST" "$KEYSTORE_DIR/boz-server.p12" << 'TLSEOF'
import sys
dest, p12path = sys.argv[1], sys.argv[2]
content = '''<?xml version="1.0" encoding="UTF-8"?>
<server>
    <!-- TLS config using file-based PKCS12 keystore (EKU serverAuth, Safari-compatible) -->
    <ssl id="defaultSSLConfig" keyStoreRef="defaultKeyStore" trustStoreRef="defaultKeyStore"/>
    <keyStore id="defaultKeyStore"
              location="{p12}"
              type="PKCS12"
              password="bozserver"/>
</server>
'''.format(p12=p12path)
with open(dest, 'wb') as f:
    f.write(content.encode('iso-8859-1'))
TLSEOF
chtag -t -c ISO8859-1 "$TLS_DEST"

echo "[gencert-eku] Done — tls.xml updated to use PKCS12 keystore with EKU serverAuth."
echo "[gencert-eku] Restart BAQBANKZ to pick up the new certificate."
