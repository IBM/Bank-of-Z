/******************************************************************
 *                                                                *
 * LICENSED MATERIALS - PROPERTY OF IBM                           *
 *                                                                *
 * (C) COPYRIGHT IBM CORP. 2026 ALL RIGHTS RESERVED               *
 *                                                                *
 * US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION,      *
 * OR DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE                   *
 * CONTRACT WITH IBM CORPORATION                                  *
 *                                                                *
******************************************************************/
package nazare.jmp.controller;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLSession;
import java.security.cert.X509Certificate;
import java.security.SecureRandom;

public class IMSBankHistory {
	// test 76
	public static void main(String[] args) {
		try {
			Class.forName("com.ibm.db2.jcc.DB2Driver");
			System.out.println("**** Loaded the JDBC driver");
			
			// Create a trust manager that accepts all certificates (for testing only!)
			// This is needed because DB2 z/OS requires SSL/TLS encryption
			TrustManager[] trustAllCerts = new TrustManager[] {
				new X509TrustManager() {
					public X509Certificate[] getAcceptedIssuers() { return null; }
					public void checkClientTrusted(X509Certificate[] certs, String authType) { }
					public void checkServerTrusted(X509Certificate[] certs, String authType) { }
				}
			};
			
			// Install the all-trusting trust manager
			SSLContext sc = SSLContext.getInstance("TLS");
			sc.init(null, trustAllCerts, new SecureRandom());
			SSLContext.setDefault(sc);
			
			// Disable hostname verification
			HostnameVerifier allHostsValid = new HostnameVerifier() {
				public boolean verify(String hostname, SSLSession session) {
					return true;
				}
			};
			HttpsURLConnection.setDefaultHostnameVerifier(allHostsValid);
			
			System.out.println("**** SSL certificate validation and hostname verification disabled");
			
			// DB2 connection parameters from DSNL004I output
			String db2Domain   = System.getProperty("db2Hostname");
			String db2Port     = System.getProperty("db2Port");
			String db2Location = System.getProperty("db2Location");
			String db2Username = System.getProperty("db2Username");
			String db2Password = System.getProperty("db2Password");
			
			// Build JDBC URL with SSL enabled
			// sslServerCertificate=false disables hostname verification in DB2 JCC driver
			String url = "jdbc:db2://" + db2Domain + ":" + db2Port + "/" + db2Location
				+ ":sslConnection=true;"
				+ "sslServerCertificate=false;"
				+ "loginTimeout=30;"
				+ "blockingReadConnectionTimeout=30;"
				+ "connectionTimeout=30;"
				+ "retrieveMessagesFromServerOnGetMessage=true;";
			
			System.out.println("**** Connecting to: " + url);
			System.out.println("**** (SSL enabled, server certificate validation disabled)");
			Connection jdbcConn = DriverManager.
					getConnection(url, db2Username, db2Password);
			jdbcConn.setAutoCommit(false);
			System.out.println("**** Created JDBC connection");
			String select = "SELECT * FROM IMSBANK.HISTORY WHERE ACCID = ?";
			PreparedStatement presta = jdbcConn.prepareStatement(select);

			System.out.println("**** Created JDBC Statement object");
			presta.setString(1, "1501");
			ResultSet rs = presta.executeQuery();
			ResultSetMetaData rsmd = rs.getMetaData();
			int columnsNumber = rsmd.getColumnCount();
			while (rs.next()) {
				for (int i = 1; i <= columnsNumber; i++) {
					if (i > 1)
						System.out.print(",  ");
					String columnValue = rs.getString(i);
					System.out.print(rsmd.getColumnName(i) + ": " + columnValue + "\n");
				}
				System.out.println("");
			}
			System.out.println("**** Fetched all rows from JDBC ResultSet");
			rs.close();
			System.out.println("**** Closed JDBC ResultSet");
			presta.close();
			System.out.println("**** Closed JDBC Statement");
			jdbcConn.commit();
			System.out.println("**** Transaction committed");
			jdbcConn.close();
			System.out.println("**** Disconnected from data source");
		} catch (ClassNotFoundException e) {
			System.err.println("Could not load JDBC driver");
			System.out.println("Exception: " + e);
			e.printStackTrace();
		} catch (java.security.NoSuchAlgorithmException | java.security.KeyManagementException e) {
			System.err.println("SSL/TLS configuration failed");
			System.out.println("Exception: " + e);
			e.printStackTrace();
		} catch (SQLException ex) {
			System.err.println("SQLException information");
			while (ex != null) {
				System.err.println("Error msg: " + ex.getMessage());
				System.err.println("SQLSTATE: " + ex.getSQLState());
				System.err.println("Error code: " + ex.getErrorCode());
				ex.printStackTrace();
				ex = ex.getNextException();
			}
		}
	} // End main
} // End SimpleJDBC
