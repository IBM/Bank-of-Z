/******************************************************************
 *                                                                *
 * LICENSED MATERIALS - PROPERTY OF IBM                           *
 *                                                                *
 * "Object Code Only (OCO)"                                       *
 *                                                                *
 * (C) COPYRIGHT IBM CORP. 2026 ALL RIGHTS RESERVED               *
 *                                                                *
 * US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION,      *
 * OR DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE                   *
 * CONTRACT WITH IBM CORPORATION                                  *
 *                                                                *
 ******************************************************************/
package nazare.jmp.controller;

import java.math.BigDecimal;
import java.nio.ByteBuffer;
import java.nio.Buffer;

import com.ibm.jzos.fields.daa.*;

import nazare.jmp.history.*;;

public class InsertHist {

	// Helper method to convert byte array to hex string (Java 11+ compatible)
	private static String bytesToHex(byte[] bytes) {
		StringBuilder sb = new StringBuilder();
		for (byte b : bytes) {
			sb.append(String.format("%02X", b));
		}
		return sb.toString();
	}

	public static void insertHist(ByteBuffer histDetail) {
		// TODO Auto-generated method stub
		try {

			TransactionService tranService = new TransactionService();

			// System.out.println("InsertTransansaction called");
			// System.out.println("buffer len = " + histDetail.capacity() + " is a direct =
			// " + histDetail.isDirect());

			int size = histDetail.capacity();
			byte[] arr = new byte[size];
			histDetail.get(arr, 0, size);
	
			// Debug output - comment out for production
			// System.out.println("histDetail = " + new String(arr));
			// System.out.println("histDetail = " + bytesToHex(arr));
	
			((Buffer)histDetail).rewind();
			long txid = histDetail.getLong(); // 8 bytes
			// System.out.println("txid=" + txid + ", ");
			
			// Read timestamp (23 bytes) - EBCDIC encoded
			byte[] ts = new byte[23];
			histDetail.get(ts, 0, 23);
			String timestamp = new String(ts, "IBM-1047"); // EBCDIC to String
			// System.out.println("ts="+ timestamp + ", ");
			
			// Read transaction type (1 byte) - EBCDIC encoded
			byte[] ttByte = new byte[1];
			histDetail.get(ttByte, 0, 1);
			String trantype = new String(ttByte, "IBM-1047"); // EBCDIC to String
			// System.out.println("type=" + trantype + ", ");
			byte[] amt = new byte[8];
			histDetail.get(amt, 0, 8);
			PackedBigDecimalField pdc = new PackedBigDecimalField(0, 15, 2);
			BigDecimal amount = pdc.getBigDecimal(amt); // 40
			// System.out.println("amount="+ amount + ", ");
			long reftxid = histDetail.getLong(); // 48
			// System.out.println("reftxid=" + reftxid + ", ");
			long accid = histDetail.getLong(); // 56
			// System.out.println("accid="+ accid + ", ");
			
			// Read balance (8 bytes) - COMP-3 packed decimal
			byte[] bal = new byte[8];
			histDetail.get(bal, 0, 8);
			PackedBigDecimalField balPdc = new PackedBigDecimalField(0, 15, 2);
			BigDecimal balance = balPdc.getBigDecimal(bal); // 64
			// System.out.println("balance="+ balance + ", ");
	
			// try {
	
			TransactionDetail tranDetail = new TransactionDetail(txid, timestamp, trantype, amount, reftxid, accid);
			tranDetail.setBalance(balance);
			tranService.saveTransactionDetail(tranDetail);
		} catch (Exception e) {
			e.printStackTrace();
		}

	}
}
