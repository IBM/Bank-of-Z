/**
 * Licensed Materials - Property of IBM
 *
 * (c) Copyright IBM Corp. 2026.
 *
 * US Government Users Restricted Rights - Use, duplication or
 * disclosure restricted by GSA ADP Schedule Contract
 * with IBM Corp.
 */
package com.ibm.boz.mq;

import java.math.BigDecimal;
import java.nio.charset.Charset;
import java.util.Arrays;

import jakarta.jms.BytesMessage;
import jakarta.jms.DeliveryMode;
import jakarta.jms.JMSConsumer;
import jakarta.jms.JMSContext;
import jakarta.jms.JMSProducer;
import jakarta.jms.JMSException;

import com.ibm.mq.constants.CMQC;
import com.ibm.mq.jakarta.jms.MQConnectionFactory;
import com.ibm.mq.jakarta.jms.MQQueue;
import com.ibm.msg.client.jakarta.wmq.WMQConstants;

/**
 * Transfer money into the Bank of Z via CICS using the MQ - CICS bridge.
 *
 * To run:
 *
 * java TransferMoneyInCICS qmgr accountNumber amount
 *
 * qmgr:          queue manager name, e.g. MQ21
 * accountNumber: eight digit account number, e.g 00000008
 * amount:        amount of money to be transferred in if positive, out if negative, e.g 99.99 or -99.99
 *
 * Before running you need to have set up STEPLIB and native library path.
 * E.g:
 *
 * export STEPLIB=MQCD94.SCSQAUTH
 * export LIBPATH=/mqm/
 */
public class TransferMoneyInCICS {
  private static final Charset EBCDIC = Charset.forName("Cp1047");

  //Offset to COBOL copy book in reply: CIH + 8 character program name.
  private static final int BASE_OFFSET = CMQC.MQCIH_LENGTH_1 + 8;

  private static String qmgr = "";
  private static String accountNumber = "";
  private static String amount = "";

  public static void main(String[] args) throws JMSException {
    if(args.length != 3) {
      System.out.println("Expected usage: java TransferMoneyInCICS qmgr accountNumber amount");
      return;
    }

    qmgr = args[0];
    accountNumber = args[1];
    amount = args[2];

    //Connect to local queue manager via bindings mode connection.
    MQConnectionFactory cf = new MQConnectionFactory();
    cf.setQueueManager(qmgr);
    cf.setTransportType(0);

    //Request queue, CICS doesn't expect RFH2 header.
    MQQueue requestQ = new MQQueue("BOZ.CICS.REQUESTQ");
    requestQ.setTargetClient(WMQConstants.WMQ_CLIENT_NONJMS_MQ);

    //Reply queue.
    MQQueue replyQ = new MQQueue("BOZ.CICS.REPLYQ");

    //Connect to MQ.
    JMSContext context = cf.createContext(JMSContext.AUTO_ACKNOWLEDGE);

    JMSProducer producer = context.createProducer();
    producer.setDeliveryMode(DeliveryMode.PERSISTENT);

    //Build up payload.
    BytesMessage requestMessage = context.createBytesMessage();

    //Add a default CIH.
    addDefaultCIH(requestMessage);

    //Program name that we want the DPL bridge to call.
    requestMessage.writeBytes("DBCRFUN ".getBytes(EBCDIC));

    //Input / output data is PAYDBCR copy book.
    //
    //    03 COMM-ACCNO               PIC X(8).           account number
    //    03 COMM-AMT                 PIC S9(10)V99.      + for credit, - for debit
    //    03 COMM-SORTC               PIC 9(6).           filled in by constant in CICS code
    //    03 COMM-AV-BAL              PIC S9(10)V99.      available balance after update
    //    03 COMM-ACT-BAL             PIC S9(10)V99.      actual balance after update
    //    03 COMM-ORIGIN.
    //         05 COMM-APPLID           PIC X(8).         APPLID of the calling region
    //         05 COMM-USERID           PIC X(8).         user id of transaction
    //         05 COMM-FACILITY-NAME    PIC X(8).         CICS terminal/facility name
    //         05 COMM-NETWRK-ID        PIC X(8).         Network ID
    //         05 COMM-FACILTYPE        PIC S9(8) COMP.   496 means no terminal, so no overdraft
    //         05 FILLER                PIC X(4).
    //    03 COMM-SUCCESS             PIC X.              Y or N
    //    03 COMM-FAIL-CODE           PIC X.              Error code: '1'=account not found, '2'=DB2 error, '3'=insufficient funds, '4'=overdraft not allowed

    requestMessage.writeBytes(accountNumber.getBytes(EBCDIC));
    requestMessage.writeBytes(zonedDecimal(new BigDecimal(amount)));
    requestMessage.writeBytes("000000".getBytes(EBCDIC));
    requestMessage.writeBytes(zonedDecimal(BigDecimal.ZERO));
    requestMessage.writeBytes(zonedDecimal(BigDecimal.ZERO));
    requestMessage.writeBytes("APPLID  ".getBytes(EBCDIC));
    requestMessage.writeBytes("USERID  ".getBytes(EBCDIC));
    requestMessage.writeBytes("FACILITY".getBytes(EBCDIC));
    requestMessage.writeBytes("NETWORK ".getBytes(EBCDIC));
    requestMessage.writeInt(0);
    requestMessage.writeBytes("    ".getBytes(EBCDIC));
    requestMessage.writeBytes("N".getBytes(EBCDIC));
    requestMessage.writeBytes("0".getBytes(EBCDIC));

    //Set necessary properties for the CICS bridge.
    requestMessage.setJMSCorrelationIDAsBytes(CMQC.MQCI_NEW_SESSION);
    requestMessage.setStringProperty(WMQConstants.JMS_IBM_FORMAT, CMQC.MQFMT_CICS);
    requestMessage.setStringProperty(WMQConstants.JMS_IBM_CHARACTER_SET, "1047");
    requestMessage.setJMSReplyTo(replyQ);

    //Send the message.
    producer.send(requestQ, requestMessage);

    //Get the reply.
    JMSConsumer consumer = context.createConsumer(replyQ);
    BytesMessage replyMessage = (BytesMessage)consumer.receive(5_000);

    if(replyMessage != null) {
      //Parse it. All offsets from the start of the COBOL copybook.
      byte[] replyBytes = new byte[(int)replyMessage.getBodyLength()];
      replyMessage.readBytes(replyBytes);

      //Check COMM-SUCCESS.
      if(getStringFromBytes(replyBytes, 90, 1).equals("Y")) {
        System.out.printf("Transfer succeeded. Available balance: %s, actual balance: %s%n", zonedDecimalToString(replyBytes, 26), zonedDecimalToString(replyBytes, 38));
      }
      else {
        System.out.printf("Transfer failed. Error code: %s%n",  getStringFromBytes(replyBytes, 91, 1));
      }
    }
    else {
      System.out.println("No reply received after 5 seconds.");
    }

    context.close();
  }

  /**
   * Add a default CIH to the message.
   *
   * @param requestMessage
   * @throws JMSException
   */
  private static void addDefaultCIH(BytesMessage requestMessage) throws JMSException {
    requestMessage.writeBytes("CIH ".getBytes(EBCDIC));
    requestMessage.writeInt(1);                   //Version
    requestMessage.writeInt(164);                 //Length
    requestMessage.writeInt(CMQC.MQENC_NATIVE);   //Encoding
    requestMessage.writeInt(CMQC.MQCCSI_Q_MGR);   //CCSID
    requestMessage.writeBytes(CMQC.MQFMT_NONE.getBytes(EBCDIC));  //Format
    requestMessage.writeInt(CMQC.MQCIH_NONE);     //Flags
    requestMessage.writeInt(CMQC.MQCRC_OK);       //ReturnCode
    requestMessage.writeInt(CMQC.MQCC_OK);        //CompletionCode
    requestMessage.writeInt(CMQC.MQRC_NONE);      //ReasonCode
    requestMessage.writeInt(CMQC.MQCUOWC_ONLY);   //UOW Control
    requestMessage.writeInt(CMQC.MQCGWI_DEFAULT); //Get wait interval
    requestMessage.writeInt(CMQC.MQCLT_PROGRAM);  //Link type
    requestMessage.writeInt(CMQC.MQCODL_AS_INPUT);//Output data length
    requestMessage.writeInt(0);                   //Facility keep time
    requestMessage.writeInt(CMQC.MQCADSD_NONE);   //ASD Descriptor
    requestMessage.writeInt(CMQC.MQCCT_NO);       //Conversational task
    requestMessage.writeInt(CMQC.MQCTES_NOSYNC);  //Task end status
    requestMessage.writeBytes(CMQC.MQCFAC_NONE);  //Facility
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Function
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Abend code
    requestMessage.writeBytes("        ".getBytes(EBCDIC));  //Authenticator
    requestMessage.writeBytes("        ".getBytes(EBCDIC));  //Reserved1
    requestMessage.writeBytes("        ".getBytes(EBCDIC));  //Reply to format
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Remote sys ID
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Remote transaction id
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Transaction id
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Facility like
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Attention ID
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Transaction start code
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Cancel code
    requestMessage.writeBytes("    ".getBytes(EBCDIC));  //Next transaction if
    requestMessage.writeBytes("        ".getBytes(EBCDIC));  //Reserved2
    requestMessage.writeBytes("        ".getBytes(EBCDIC));  //Reserved3
  }

  /**
   * Get an EBCDIC string from a byte array.
   *
   * @param bytes
   * @param offset
   * @param length
   * @return
   */
  private static String getStringFromBytes(byte[] bytes, int offset, int length) {
    return new String(bytes, BASE_OFFSET  + offset, length, EBCDIC);
  }

  /**
   * Decodes an EBCDIC zoned decimal byte array for a COBOL PIC S9(10)V99 field (12 bytes)
   * into a human-readable decimal string, e.g. "12345.67" or "-12345.67".
   *
   * The last byte encodes the sign in its high nibble: 0xC = positive, 0xD = negative.
   * All bytes encode a single decimal digit in their low nibble (0x0–0x9).
   *
   * @param inputBytes  a byte array containing a zoned decimal at the provided offset
   * @param offset the offset of the zoned decimal
   * @return       a string representation of the value, e.g. "-12345.67"
   * @throws IllegalArgumentException if the array is not exactly 12 bytes or contains invalid digits
   */
  private static String zonedDecimalToString(byte[] inputBytes, int offset) {
    if (inputBytes.length - BASE_OFFSET - offset <= 12) {
      throw new IllegalArgumentException("Not enough space for PIC S9(10)V99 field.");
    }

    byte[] bytes = Arrays.copyOfRange(inputBytes, BASE_OFFSET + offset, BASE_OFFSET + offset + 12);

    // Determine sign from the high nibble of the last byte.
    int signNibble = (bytes[11] & 0xFF) >> 4;
    boolean negative = signNibble == 0xD;

    // Extract all 12 digits from the low nibbles.
    StringBuilder digits = new StringBuilder(12);
    for (int i = 0; i < 12; i++) {
      int digit = bytes[i] & 0x0F;
      if (digit > 9) {
        throw new IllegalArgumentException("Invalid zoned decimal digit at byte " + i + ": 0x" + Integer.toHexString(bytes[i] & 0xFF));
      }
      digits.append((char) ('0' + digit));
    }

    // Insert decimal point: S9(10)V99 means 10 integer digits + 2 fractional digits.
    digits.insert(10, '.');

    // Strip leading zeros from the integer part, keeping at least one digit.
    String result = digits.toString().replaceFirst("^0+(?=\\d)", "");

    return negative ? "-" + result : result;
  }

  /**
   * Encodes a BigDecimal as EBCDIC zoned decimal bytes for a COBOL PIC S9(10)V99 field (12 bytes).
   *
   * @param value the value to encode
   * @return byte array of length 12
   */
  private static byte[] zonedDecimal(BigDecimal value) {
    boolean negative = value.signum() < 0;
    String digits = value.abs().movePointRight(2).toBigIntegerExact().toString();
    if (digits.length() > 12) {
      throw new IllegalArgumentException("Value " + value + " overflows PIC S9(10)V99");
    }
    while (digits.length() < 12) digits = "0" + digits;
    byte[] result = new byte[12];
    for (int i = 0; i < 12; i++) {
      result[i] = (byte) (0xF0 | (digits.charAt(i) - '0'));
    }
    // Embed sign in last byte: 0xC = positive, 0xD = negative
    result[11] = (byte) ((negative ? 0xD0 : 0xC0) | (digits.charAt(11) - '0'));
    return result;
  }
}