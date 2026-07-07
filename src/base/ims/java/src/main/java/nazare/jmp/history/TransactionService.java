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
package nazare.jmp.history;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;

public class TransactionService {

	// DB2 location can be set via system property: -Ddb2.location=DBD1LOC
	// Default to DBD1LOC if not specified
	private static final String DB2_LOCATION = System.getProperty("db2.location", "DBD1LOC");

	public List<TransactionDetail> getTransactionDetail(long accountNumber) {
		List<TransactionDetail> tranList = null;

		try {
			System.out.println("******** testing: " + java.time.LocalDateTime.now() + " *********");
			String url = "jdbc:db2:" + DB2_LOCATION;  // DB2 Location (configurable via -Ddb2.location system property)
			// Other possible locations:
			// DALLASD - DB2 Location on zD&T
			// DALLASC - DB2 Location on zD&T
			// DBC1 - DB2 Location on TIVLP02
			Class.forName("com.ibm.db2.jcc.DB2Driver");
			System.out.println("**** Loaded the JDBC driver: " + url);
			Connection jdbcConn = DriverManager.getConnection(url);
			jdbcConn.setAutoCommit(false);
			System.out.println("**** Created JDBC connection" + url);
			
			// First, get current account balance from IMS ACCOUNT table
			// Note: This would ideally come from IMS, but for now we'll calculate from transactions
			String select = "SELECT * FROM IMSBANK.HISTORY WHERE ACCID = ? ORDER BY TIMESTMP DESC FETCH FIRST 50 ROWS ONLY";
			PreparedStatement presta = jdbcConn.prepareStatement(select);

			System.out.println("**** Created JDBC Statement object");
			presta.setLong(1, accountNumber);
			System.out.println("**** Execute JDBC Statement object");
			ResultSet rs = presta.executeQuery();
			ResultSetMetaData rsmd = rs.getMetaData();
			int columnsNumber = rsmd.getColumnCount();
			tranList = new ArrayList<TransactionDetail>();
			while (rs.next()) {
				TransactionDetail tranDetail = new TransactionDetail();
				for (int i = 1; i <= columnsNumber; i++) {
					// if (i > 1) System.out.print(", ");
					String columnName = rsmd.getColumnName(i);

					// build tran array
					switch (columnName) {
						case "TXID":
							tranDetail.setTxid(rs.getLong(i));
							// System.out.println(rs.getLong(i));
							break;
						case "TIMESTMP":
							tranDetail.setTimestmp(rs.getString(i));
							// System.out.println(rs.getString(i));
							break;
						case "TRANSTYP":
							tranDetail.setTranstyp(rs.getString(i));
							// System.out.println(rs.getString(i));
							break;
						case "AMOUNT":
							tranDetail.setAmount(rs.getBigDecimal(i));
							// System.out.println(rs.getDouble(i));
							break;
						case "REFTXID":
							tranDetail.setReftxid(rs.getLong(i));
							// System.out.println(rs.getLong(i));
							break;
						case "BALANCE":
							tranDetail.setBalance(rs.getBigDecimal(i));
							// System.out.println(rs.getBigDecimal(i));
							break;

						default:
							break;
					}
				}

				tranDetail.setAccid(accountNumber);
				// System.out.println(accountNumber);
				tranList.add(tranDetail);
				// System.out.println("");
			}
			System.out.println("**** Closed JDBC ResultSet");
			rs.close();
			System.out.println("**** Closed JDBC Statement");
			presta.close();
			System.out.println("**** Disconnected from data source");
			jdbcConn.close();
		} catch (ClassNotFoundException e) {
			System.err.println("Could not load JDBC driver");
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

		return tranList;
	}

	public String saveTransactionDetail(TransactionDetail inputTran) {

		try {
			Class.forName("com.ibm.db2.jcc.DB2Driver");
			System.out.println("**** Loaded the JDBC driver");
			String url = "jdbc:db2:" + DB2_LOCATION;  // DB2 Location (configurable via -Ddb2.location system property)
			// Other possible locations:
			// db2:default:connection - default connection
			// DALLASD - DB2 Location on zD&T
			// jdbc:db2://tivlp02.svl.ibm.com:5050/DBC1 - Type 4 remote connection
			Connection jdbcConn = DriverManager.getConnection(url);
			jdbcConn.setAutoCommit(false);
			System.out.println("**** Created JDBC connection");

			// the mysql insert statement
			String query = " INSERT INTO IMSBANK.HISTORY (TIMESTMP, TXID, TRANSTYP, AMOUNT, REFTXID, ACCID, BALANCE)"
					+ " values (?, ?, ?, ?, ?, ?, ?)";

			// create the mysql insert preparedstatement
			PreparedStatement preparedStmt = jdbcConn.prepareStatement(query);
			preparedStmt.setString(1, inputTran.getTimestmp());
			preparedStmt.setLong(2, inputTran.getTxid());
			preparedStmt.setString(3, inputTran.getTranstyp());
			preparedStmt.setBigDecimal(4, inputTran.getAmount());
			preparedStmt.setLong(5, inputTran.getReftxid());
			preparedStmt.setLong(6, inputTran.getAccid());
			preparedStmt.setBigDecimal(7, inputTran.getBalance());

			// execute the preparedstatement
			System.out.println("**** Execute JDBC Statement object");
			System.out.println(preparedStmt.executeUpdate() + " record inserted");

			System.out.println("**** Close prepare statements - july 30 6:24 AM ");
			preparedStmt.close();

			System.out.println("**** Disconnected from data source");
			jdbcConn.close();
		} catch (ClassNotFoundException e) {
			System.err.println("Could not load JDBC driver");
			System.out.println("Exception: " + e);
			e.printStackTrace();
			return e.toString();
		} catch (SQLException ex) {
			System.err.println("SQLException information");
			while (ex != null) {
				System.err.println("Error msg: " + ex.getMessage());
				System.err.println("SQLSTATE: " + ex.getSQLState());
				System.err.println("Error code: " + ex.getErrorCode());
				ex.printStackTrace();
				ex = ex.getNextException();
				return ex.toString();
			}
		}

		return "success";
	}

}
