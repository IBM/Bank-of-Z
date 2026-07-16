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

import java.nio.charset.Charset;

import jakarta.jms.BytesMessage;
import jakarta.jms.DeliveryMode;
import jakarta.jms.JMSConsumer;
import jakarta.jms.JMSContext;
import jakarta.jms.JMSProducer;

import com.ibm.mq.constants.CMQC;
import com.ibm.mq.jakarta.jms.MQConnectionFactory;
import com.ibm.mq.jakarta.jms.MQQueue;
import com.ibm.msg.client.jakarta.wmq.WMQConstants;

public class TransferMoneyIn {

  public static void main(String[] args) throws Exception {
    MQConnectionFactory cf = new MQConnectionFactory();

    //TODO: need to abstract this away either in JNDI or as properties.
    cf.setQueueManager("MQ21");
    cf.setTransportType(0);

    MQQueue requestQ = new MQQueue("BOZ.CICS.REQUESTQ");
    //Don't append an RFH2 header
    requestQ.setTargetClient(WMQConstants.WMQ_CLIENT_NONJMS_MQ);

    MQQueue replyQ = new MQQueue("BOZ.CICS.REPLYQ");

    JMSContext context = cf.createContext(JMSContext.AUTO_ACKNOWLEDGE);

    JMSProducer producer = context.createProducer();

    producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT);

    BytesMessage m = context.createBytesMessage();

    //Add the CIH.
    //TODO: do we need this
    Charset EBCDIC = Charset.forName("Cp1047");
    m.writeBytes("CIH ".getBytes(EBCDIC));
    m.writeInt(1);                   //Version
    m.writeInt(164);                 //Length
    m.writeInt(CMQC.MQENC_NATIVE);   //Encoding
    m.writeInt(CMQC.MQCCSI_Q_MGR);   //CCSID
    m.writeBytes(CMQC.MQFMT_STRING.getBytes(EBCDIC));  //Format
    m.writeInt(CMQC.MQCIH_NONE);     //Flags
    m.writeInt(CMQC.MQCRC_OK);       //ReturnCode
    m.writeInt(CMQC.MQCC_OK);        //CompletionCode
    m.writeInt(CMQC.MQRC_NONE);      //ReasonCode
    m.writeInt(CMQC.MQCUOWC_ONLY);   //UOW Control
    m.writeInt(CMQC.MQCGWI_DEFAULT); //Get wait interval
    m.writeInt(CMQC.MQCLT_PROGRAM);  //Link type
    m.writeInt(CMQC.MQCODL_AS_INPUT);//Output data length
    m.writeInt(0);                   //Facility keep time
    m.writeInt(CMQC.MQCADSD_NONE);   //ASD Descriptor
    m.writeInt(CMQC.MQCCT_NO);       //Conversational task
    m.writeInt(CMQC.MQCTES_NOSYNC);  //Task end status
    m.writeBytes(CMQC.MQCFAC_NONE);  //Facility
    m.writeBytes("    ".getBytes(EBCDIC));  //Function
    m.writeBytes("    ".getBytes(EBCDIC));  //Abend code
    m.writeBytes("        ".getBytes(EBCDIC));  //Authenticator
    m.writeBytes("        ".getBytes(EBCDIC));  //Reserved1
    m.writeBytes("        ".getBytes(EBCDIC));  //Reply to format
    m.writeBytes("    ".getBytes(EBCDIC));  //Remote sys ID
    m.writeBytes("    ".getBytes(EBCDIC));  //Remote transaction id
    m.writeBytes("    ".getBytes(EBCDIC));  //Transaction id
    m.writeBytes("    ".getBytes(EBCDIC));  //Facility like
    m.writeBytes("    ".getBytes(EBCDIC));  //Attention ID
    m.writeBytes("    ".getBytes(EBCDIC));  //Transaction start code
    m.writeBytes("    ".getBytes(EBCDIC));  //Cancel code
    m.writeBytes("    ".getBytes(EBCDIC));  //Next transaction if
    m.writeBytes("        ".getBytes(EBCDIC));  //Reserved2
    m.writeBytes("        ".getBytes(EBCDIC));  //Reserved3

    //Build up payload.
    //Program name that we want the DPL bridge to call.
    m.writeBytes("DBCRFUN ".getBytes(EBCDIC));

//    03 COMM-ACCNO               PIC X(8).           account number
//    03 COMM-AMT                 PIC S9(10)V99.      + for credit, - for debit
//    03 COMM-SORTC               PIC 9(6).           filled in by constant in CICS codce
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

    //INput:
    // COMM-ACCNO, COMM-ACCNO, COMM-FACILTYPE, COMM-ORIGIN(COMM-APPLID/COMM-USERID)

    //Output:
    // COMM-AV-BAL, COMM-ACT-BAL, COMM-SUCCESS, COMM-FAIL-CODE

    //Not used: COMM-FACILITY-NAME, COMM-NETWRK-ID

    //Hard coded for the moment.
    m.writeBytes("00000008".getBytes(EBCDIC));      //Account number
    m.writeBytes("+000000009999".getBytes(EBCDIC)); //Amount. 99.99
    m.writeBytes("987654".getBytes(EBCDIC));        //Sort code
    m.writeBytes("+000000000000".getBytes(EBCDIC)); //not used on request
    m.writeBytes("+000000000000".getBytes(EBCDIC)); //not used on request
    m.writeBytes("APPLID  ".getBytes(EBCDIC));
    m.writeBytes("USERID  ".getBytes(EBCDIC));
    m.writeBytes("FACILITY".getBytes(EBCDIC));
    m.writeBytes("NETWORK ".getBytes(EBCDIC));
    m.writeInt(0);                                  //Facility type
    m.writeBytes("    ".getBytes(EBCDIC));          //Filler
    m.writeBytes("N".getBytes(EBCDIC));
    m.writeBytes("0".getBytes(EBCDIC));


    //Tell CICS bridge that this is something that it should actually process!
    m.setJMSCorrelationIDAsBytes(CMQC.MQCI_NEW_SESSION);

    m.setStringProperty(WMQConstants.JMS_IBM_FORMAT, CMQC.MQFMT_CICS);
    m.setStringProperty(WMQConstants.JMS_IBM_CHARACTER_SET, "1047");
    m.setJMSReplyTo(replyQ);


    producer.send(requestQ, m);

    JMSConsumer consumer = context.createConsumer(replyQ);
    System.out.println(consumer.receive(5_000));


    //TODO: do something with request
  }
}
