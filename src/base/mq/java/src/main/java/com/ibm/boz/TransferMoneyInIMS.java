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
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.Charset;

import jakarta.jms.BytesMessage;
import jakarta.jms.DeliveryMode;
import jakarta.jms.JMSConsumer;
import jakarta.jms.JMSContext;
import jakarta.jms.JMSProducer;
import jakarta.jms.JMSException;

import com.ibm.mq.jakarta.jms.MQConnectionFactory;
import com.ibm.mq.jakarta.jms.MQQueue;
import com.ibm.msg.client.jakarta.wmq.WMQConstants;

/**
 * Transfer money into the Bank of Z via IMS using the MQ - IMS bridge.
 *
 * To run:
 *
 *   java TransferMoneyInIMS qmgr accountId customerId amount
 *
 *   qmgr:        queue manager name, e.g. MQ21
 *   accountId:   18-digit account ID, e.g. 000000000000000001
 *   customerId:  9-digit customer ID, e.g. 000000001
 *   amount:      amount of money to be transferred in if positive, out if negative, e.g 99.99 or -99.99
 *
 * Before running you need to have set up STEPLIB and native library path.
 * E.g:
 *
 *   export STEPLIB=MQCD94.SCSQAUTH
 *   export LIBPATH=/mqm/
 */
public class TransferMoneyInIMS {

  private static final Charset EBCDIC = Charset.forName("Cp1047");

  // IBTRAN INPUT-AREA layout (bytes, after LL+ZZ+tran-code):
  //   IN-ACCID    PIC X(18)
  //   IN-AMOUNT   PIC X(16)
  //   IN-TRXTYPE  PIC X(1)
  //   IN-CUSTID   PIC X(9)
  private static final int INPUT_ACCID_LEN   = 18;
  private static final int INPUT_AMOUNT_LEN  = 16;
  private static final int INPUT_TRXTYPE_LEN =  1;
  private static final int INPUT_CUSTID_LEN  =  9;
  private static final int TRAN_CODE_LEN     =  8;

  // IBTRAN OUTPUT-AREA layout (bytes, after LL+ZZ):
  //   MSG-OUT        PIC X(43)    — balance string on success, error text on failure
  //   TOTAL-ACCS     PIC 9(1)     — number of account summary entries (0–6)
  // Per account-summary entry (COMP-3 / COMP-5 binary, big-endian):
  //   BALANCE-AS     PIC S9(13)V9(2) COMP-3  → 8 bytes packed decimal
  //   ACCTYPE-AS     PIC X(1)                → 1 byte character
  //   ACCID-AS       PIC S9(18) COMP-5       → 8 bytes binary
  private static final int OUTPUT_LL_ZZ_LEN  =  4;
  private static final int OUTPUT_MSG_LEN    = 43;
  private static final int OUTPUT_TOTAL_LEN  =  1;
  private static final int ACCSUMM_BAL_LEN   =  8;  // COMP-3 packed
  private static final int ACCSUMM_TYPE_LEN  =  1;
  private static final int ACCSUMM_ID_LEN    =  8;  // COMP-5 binary
  private static final int ACCSUMM_ENTRY_LEN = ACCSUMM_BAL_LEN + ACCSUMM_TYPE_LEN + ACCSUMM_ID_LEN;

  public static void main(String[] args) throws JMSException {
    if (args.length != 4) {
      System.out.println("Expected usage: java TransferMoneyInIMS qmgr accountId customerId amount");
      return;
    }

    String qmgr = args[0];
    String accountId = args[1];
    String customerId = args[2];
    String amount  = args[3];

    // Derive IBTRAN's IN-TRXTYPE from the sign of amount.
    boolean negative = amount.startsWith("-");
    String trxType   = negative ? "w" : "d";
    // Strip the leading minus — IN-AMOUNT is an unsigned numeric string.
    String absAmount = negative ? amount.substring(1) : amount;

    // Connect to local queue manager via bindings mode.
    MQConnectionFactory cf = new MQConnectionFactory();
    cf.setQueueManager(qmgr);
    cf.setTransportType(0);

    // Request queue — IMS bridge does not use RFH2.
    MQQueue requestQ = new MQQueue("BOZ.IMS.REQUESTQ");
    requestQ.setTargetClient(WMQConstants.WMQ_CLIENT_NONJMS_MQ);

    // Reply queue.
    MQQueue replyQ = new MQQueue("BOZ.IMS.REPLYQ");

    JMSContext context = cf.createContext(JMSContext.AUTO_ACKNOWLEDGE);

    JMSProducer producer = context.createProducer();
    producer.setDeliveryMode(DeliveryMode.PERSISTENT);

    // Build the IMS input message.
    // Layout: LL(2) + ZZ(2) + TRAN-CODE(8) + IN-ACCID(18) + IN-AMOUNT(16) + IN-TRXTYPE(1) + IN-CUSTID(9)
    // LL is the total length of the segment including the LL and ZZ fields themselves.
    int segLen = 2 + 2 + TRAN_CODE_LEN + INPUT_ACCID_LEN + INPUT_AMOUNT_LEN + INPUT_TRXTYPE_LEN + INPUT_CUSTID_LEN;

    BytesMessage requestMessage = context.createBytesMessage();

    // LL and ZZ — both big-endian shorts.
    requestMessage.writeShort((short) segLen);
    requestMessage.writeShort((short) 0);

    // Transaction code, space-padded to 8 bytes in EBCDIC.
    requestMessage.writeBytes("IBTRAN  ".getBytes(EBCDIC));

    // IN-ACCID: right-justified in 18 bytes, space-padded on the left.
    requestMessage.writeBytes(padLeft(accountId, INPUT_ACCID_LEN).getBytes(EBCDIC));

    // IN-AMOUNT: right-justified in 16 bytes, space-padded on the left (always unsigned).
    requestMessage.writeBytes(padLeft(absAmount, INPUT_AMOUNT_LEN).getBytes(EBCDIC));

    // IN-TRXTYPE: single character.
    requestMessage.writeBytes(trxType.getBytes(EBCDIC));

    // IN-CUSTID: right-justified in 9 bytes, space-padded on the left.
    requestMessage.writeBytes(padLeft(customerId, INPUT_CUSTID_LEN).getBytes(EBCDIC));

    // IMS MQ bridge message properties.
    requestMessage.setStringProperty(WMQConstants.JMS_IBM_FORMAT, "MQIMSVS ");
    requestMessage.setStringProperty(WMQConstants.JMS_IBM_CHARACTER_SET, "1047");
    requestMessage.setJMSReplyTo(replyQ);

    // Send.
    producer.send(requestQ, requestMessage);

    // Wait up to 5 seconds for the reply.
    JMSConsumer consumer = context.createConsumer(replyQ);
    BytesMessage replyMessage = (BytesMessage) consumer.receive(5_000);

    if (replyMessage != null) {
      System.out.println(replyMessage);

      byte[] reply = new byte[(int) replyMessage.getBodyLength()];
      replyMessage.readBytes(reply);

      parseAndPrintReply(reply);
    } else {
      System.out.println("No reply received after 5 seconds.");
    }

    context.close();
  }

  /**
   * Parses and prints the IBTRAN OUTPUT-AREA from the raw IMS reply segment bytes.
   *
   * The reply body is: LL(2) + ZZ(2) + MSG-OUT(43) + TOTAL-ACCS(1) + N × account-summary(17)
   */
  private static void parseAndPrintReply(byte[] reply) {
    int offset = OUTPUT_LL_ZZ_LEN;  // skip LL + ZZ

    // MSG-OUT is 43 EBCDIC bytes — either a formatted balance on success or an error message.
    String msgOut = new String(reply, offset, OUTPUT_MSG_LEN, EBCDIC).trim();
    offset += OUTPUT_MSG_LEN;

    // TOTAL-ACCS is a single EBCDIC zoned digit (PIC 9).
    int totalAccs = reply[offset] & 0x0F;
    offset += OUTPUT_TOTAL_LEN;

    // A successful balance response starts with a digit or space (the Z(13).99 picture).
    // An error response contains letters.
    boolean success = totalAccs > 0 && msgOut.matches("[\\s\\d.,+-]+");

    if (success) {
      System.out.println("Transfer succeeded. New balance: " + msgOut.trim());
      System.out.println("Account summary (" + totalAccs + " account(s)):");
      for (int i = 0; i < totalAccs && offset + ACCSUMM_ENTRY_LEN <= reply.length; i++) {
        BigDecimal balance = unpackComp3(reply, offset, ACCSUMM_BAL_LEN, 2);
        offset += ACCSUMM_BAL_LEN;
        String accType = new String(reply, offset, ACCSUMM_TYPE_LEN, EBCDIC);
        offset += ACCSUMM_TYPE_LEN;
        long accId = ByteBuffer.wrap(reply, offset, ACCSUMM_ID_LEN).order(ByteOrder.BIG_ENDIAN).getLong();
        offset += ACCSUMM_ID_LEN;
        System.out.printf("Transfer succeeded. Available balance=%s", balance.toPlainString());
      }
    } else {
      System.out.println("Transfer failed: " + msgOut.trim());
    }
  }

  /**
   * Decodes a COBOL COMP-3 (packed decimal) field into a BigDecimal.
   *
   * Each byte holds two decimal digits in its nibbles. The low nibble of the
   * last byte holds the sign: 0xC or 0xF = positive, 0xD = negative.
   *
   * @param bytes       source byte array
   * @param offset      start of the packed field
   * @param len         number of bytes in the packed field
   * @param scale       number of implied decimal places (V digits)
   * @return            the decoded value
   */
  private static BigDecimal unpackComp3(byte[] bytes, int offset, int len, int scale) {
    StringBuilder digits = new StringBuilder();
    for (int i = offset; i < offset + len - 1; i++) {
      digits.append((bytes[i] >> 4) & 0x0F);
      digits.append(bytes[i] & 0x0F);
    }
    // Last byte: high nibble = last digit, low nibble = sign.
    byte last = bytes[offset + len - 1];
    digits.append((last >> 4) & 0x0F);
    boolean negative = (last & 0x0F) == 0xD;

    BigInteger unscaled = new BigInteger(digits.toString());
    BigDecimal result = new BigDecimal(unscaled, scale);
    return negative ? result.negate() : result;
  }

  /**
   * Left-pads a string with spaces to the given width (numeric character fields).
   */
  private static String padLeft(String s, int width) {
    return String.format("%" + width + "s", s);
  }
}
