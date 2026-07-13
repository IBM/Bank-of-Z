#!/bin/sh
# =============================================================================
# Script  : gencert-eku.sh
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
# 2. Write and compile the Java cert-generation program
# -----------------------------------------------------------------------
cat > "$TMPDIR/GenCert.java" << 'JAVAEOF'
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.asn1.*;
import org.bouncycastle.cert.X509v3CertificateBuilder;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import java.io.*;
import java.math.BigInteger;
import java.security.*;
import java.security.cert.X509Certificate;
import java.time.*;
import java.util.Date;
import javax.net.ssl.KeyManagerFactory;
import java.security.KeyStore;

public class GenCert {
    public static void main(String[] args) throws Exception {
        // args: caP12Path caPassword outP12Path outPassword ip dns notAfter
        String caPath    = args[0];
        String caPass    = args[1];
        String outPath   = args[2];
        String outPass   = args[3];
        String ip        = args[4];
        String dns       = args[5];
        String notAfter  = args[6]; // yyyy-MM-dd

        // Load CA PKCS12
        KeyStore caKs = KeyStore.getInstance("PKCS12");
        try (InputStream in = new FileInputStream(caPath)) {
            caKs.load(in, caPass.toCharArray());
        }
        String caAlias = caKs.aliases().nextElement();
        PrivateKey caKey = (PrivateKey) caKs.getKey(caAlias, caPass.toCharArray());
        X509Certificate caCert = (X509Certificate) caKs.getCertificate(caAlias);

        // Generate new RSA keypair for the server cert
        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(2048, new SecureRandom());
        KeyPair kp = kpg.generateKeyPair();

        // Dates
        Date notBefore = new Date();
        LocalDate exp = LocalDate.parse(notAfter);
        Date notAfterDate = Date.from(exp.atStartOfDay(ZoneOffset.UTC).toInstant());

        X500Name subject = new X500Name("CN=Bank of Z,OU=IBM BoZ,O=IBM,C=US");
        X500Name issuer  = new X500Name(caCert.getSubjectX500Principal().getName());

        JcaX509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
            issuer,
            BigInteger.valueOf(System.currentTimeMillis()),
            notBefore,
            notAfterDate,
            subject,
            kp.getPublic()
        );

        // SAN: IP + DNS
        GeneralName[] sans = new GeneralName[] {
            new GeneralName(GeneralName.iPAddress,   ip),
            new GeneralName(GeneralName.dNSName,     dns)
        };
        builder.addExtension(Extension.subjectAlternativeName, false,
            new GeneralNames(sans));

        // Key Usage: digitalSignature + keyEncipherment
        builder.addExtension(Extension.keyUsage, true,
            new KeyUsage(KeyUsage.digitalSignature | KeyUsage.keyEncipherment));

        // Extended Key Usage: serverAuth (1.3.6.1.5.5.7.3.1)
        builder.addExtension(Extension.extendedKeyUsage, false,
            new ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuthentication));

        // Sign with VSICA
        ContentSigner signer = new JcaContentSignerBuilder("SHA256withRSA")
            .build(caKey);
        X509Certificate cert = new JcaX509CertificateConverter()
            .getCertificate(builder.build(signer));

        // Write output PKCS12
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
JAVAEOF

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
# 4. Copy the PKCS12 to a RACF-importable dataset and import it
# -----------------------------------------------------------------------
echo "[gencert-eku] Importing new cert into RACF..."

# Delete the old BoZ cert from the ring and RACF first
tsocmd "RACDCERT ID($userid) REMOVE(LABEL('$label') RING($ring))" \
  >/dev/null 2>&1 || true
tsocmd "RACDCERT ID($userid) DELETE(LABEL('$label'))" \
  >/dev/null 2>&1 || true
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH" >/dev/null 2>&1

# Copy new PKCS12 to dataset for RACDCERT IMPORT
cp "$TMPDIR/boz-server.p12" "//'${userid}.BOZ.NEWCERT'"

tsocmd "RACDCERT IMPORT(DSN('${userid}.BOZ.NEWCERT')) \
  ID($userid) \
  WITHLABEL('$label') \
  PASSWORD('bozserver')"
tsocmd "RACDCERT ID($userid) \
  CONNECT(LABEL('$label') RING($ring) DEFAULT)"
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH"

echo "[gencert-eku] Done — BoZ cert now has EKU serverAuth, Safari should trust it."
