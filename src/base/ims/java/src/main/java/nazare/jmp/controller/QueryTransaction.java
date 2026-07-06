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

import java.io.ByteArrayOutputStream;
import java.util.Arrays;
import java.util.List;

import com.ibm.ims.dli.DLIException;
import com.ibm.ims.dli.tm.Application;
import com.ibm.ims.dli.tm.ApplicationFactory;
import com.ibm.ims.dli.tm.IOMessage;
import com.ibm.ims.dli.tm.IOMessageImpl;
import com.ibm.ims.dli.tm.MessageQueue;
import com.ibm.ims.dli.tm.Transaction;

import nazare.jmp.history.*;

public class QueryTransaction {

	public static void main(String[] args) {
//		System.out.println("******** testing: " + java.time.LocalDateTime.now() + " *********");

		System.out.println("QueryTransansaction called");

		TransactionService tranService = new TransactionService();

		// Application is used to get a Transaction object
		Application app = ApplicationFactory.createApplication();

		// Transaction is primarily used for commit or rollback calls
		Transaction tran = app.getTransaction();

		// Get a handle to the MessageQueue object for sending and receiving
		// messages to and from the IMS message queue
		MessageQueue messageQueue = app.getMessageQueue();

		IOMessage inputMessage = null;
		IOMessage tranHistoryOutputMessage = null;

		try {

			// initialize the input and output messages to the IOMessage object
			inputMessage = app.getIOMessage("class://nazare.jmp.message.InputMessage");
			tranHistoryOutputMessage = app.getIOMessage("class://nazare.jmp.message.TranHistoryOutputMessage");

			// get a InputMessage message from the queue, if there is one
			while (messageQueue.getUnique(inputMessage)) {

				// get the account number from the InputMessage
				System.out.println("Input Message: " + inputMessage.toString());
				String accountNumber = inputMessage.getString("accountNumber");

				List<TransactionDetail> tranDetail = tranService.getTransactionDetail(Long.parseLong(accountNumber.trim()));

				// if account history is found then return the information
				if (tranDetail != null) {

					int numOfTrans = tranDetail.size();
					System.out.println(numOfTrans + " transactions found");

					// output message header
					tranHistoryOutputMessage.clear();
					tranHistoryOutputMessage.setString("MSG-OUT", "Success");
					tranHistoryOutputMessage.setInt("TOTAL-TX", numOfTrans);

					IOMessage histDetail = app.getIOMessage("class://nazare.jmp.message.TranHistoryDetail");

					ByteArrayOutputStream baos = new ByteArrayOutputStream();

					for (TransactionDetail td : tranDetail) {

						histDetail.setLong("TXID", td.getTxid());
						histDetail.setString("TIMESTMP", td.getTimestmp());
						histDetail.setString("TRANSTYP", td.getTranstyp());
						histDetail.setString("AMOUNT", String.format("%-18.2f", td.getAmount())); // right padded with spaces
						histDetail.setLong("REFTXID", td.getReftxid());
						histDetail.setLong("ACCID", td.getAccid());
						histDetail.setString("BALANCE", String.format("%-18.2f", td.getBalance())); // right padded with spaces
						// System.out.println("histDetail = " + new
						// String(((IOMessageImpl)histDetail).getIOArea(), "cp1047"));
						// System.out.println("histDetail = " +
						// DatatypeConverter.printHexBinary(((IOMessageImpl)histDetail).getIOArea()));
						// System.out.println("histDetail length = " + histDetail.getActualLength());
						baos.write(((IOMessageImpl) histDetail).getIOArea(), 13, 84); // get history detail starting at offset 13, now 84 bytes (was 66)

					}

					// System.out.println("Getting storage for output message");
					byte[] histDetailIOA = new byte[] {};
					histDetailIOA = baos.toByteArray();
					byte[] arr2 = Arrays.copyOf(histDetailIOA, 4200); // up to 50 history records * 84 bytes (was 3300)
					// System.out.println("arr2 = " + new String(arr2, "cp1047"));
					// System.out.println("arr2 = " + DatatypeConverter.printHexBinary(arr2));
					tranHistoryOutputMessage.setBytes("TX-DETAIL", arr2);
					// System.out.println("output length = " +
					// tranHistoryOutputMessage.getActualLength());
					// byte[] ioa = ((IOMessageImpl)tranHistoryOutputMessage).getIOArea();
					// System.out.println(new String(ioa, "cp1047"));
					// System.out.println(DatatypeConverter.printHexBinary(ioa));
					messageQueue.insert(tranHistoryOutputMessage, MessageQueue.DEFAULT_DESTINATION);

					tran.commit();

				} // end if customer not null

			} // end getUnique while loop

			// System.out.println("No more input message!!");

		} catch (Exception e) {

			System.out.println(e.getMessage());

			try {

				if (e.getMessage().length() > 500) {
					tranHistoryOutputMessage.setString("MSG-OUT", e.getMessage().substring(0, 500));
				} else {
					tranHistoryOutputMessage.setString("MSG-OUT", e.getMessage());
				}
				messageQueue.insert(tranHistoryOutputMessage, MessageQueue.DEFAULT_DESTINATION);

			} catch (DLIException e1) {
				System.out.println("DLIException encountered");
				System.out.println(e1.getMessage());
			}

		} finally {

			app.end();

		}

	}
}
