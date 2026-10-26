/**
 * Licensed Materials - Property of IBM
 *
 * (c) Copyright IBM Corp. 2026.
 *
 * US Government Users Restricted Rights - Use, duplication or
 * disclosure restricted by GSA ADP Schedule Contract
 * with IBM Corp.
 */
package com.ibm.boq;

import jakarta.jms.JMSException;

/**
 * Transfer money into the Bank of Z from the Bank of Q via IBM MQ for z/OS.
 *
 * To run:
 *
 * java TransferMoneyToBOZ qmgr accountNumber amount
 *
 * qmgr:          queue manager name, e.g. MQ21
 * customerID:    customer ID, e.g. C1234 or I000000015
 * accountNumber: account number, e.g 00000008
 * amount:        amount of money to be transferred in if positive, out if negative, e.g 99.99 or -99.99
 *
 * Before running you need to have set up STEPLIB and native library path.
 * E.g:
 *
 * export STEPLIB=MQCD94.SCSQAUTH
 * export LIBPATH=/mqm/
 */
public class TransferMoneyToBOZ {

  public static void main(String[] args) throws JMSException {
    if(args.length != 4) {
      System.out.println("Expected usage: java TransferMoneyToBOZ qmgr customerID accountNumber amount");
      return;
    }

    String qmgr = args[0];
    String customerID = args[1];
    String accountNumber = args[2];
    String amount = args[3];

    if(qmgr.length() > 4 || qmgr.length() == 0) {
      System.out.println("Incorrect queue manager name");
      return;
    }

    if(customerID.length() < 1     ||
       !(customerID.charAt(0) =='C' || customerID.charAt(0) =='I')) {
      System.out.println("Incorrect customerID");
      return;
    }

    try {
      Integer.parseInt(accountNumber);
    }
    catch(NumberFormatException e) {
      System.out.println("Incorrect accountNumber");
      return;
    }

    try {
      Float.parseFloat(amount);
    }
    catch(NumberFormatException e) {
      System.out.println("Incorrect amount");
      return;
    }

    if(customerID.charAt(0) == 'C') {
      new TransferMoneyToBOZViaCICS(qmgr, accountNumber, amount).performTransfer();
    }
    else {
      new TransferMoneyToBOZViaIMS(qmgr, customerID, accountNumber, amount).performTransfer();
    }
  }
}