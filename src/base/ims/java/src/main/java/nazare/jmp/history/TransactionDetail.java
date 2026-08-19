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
package nazare.jmp.history;

import java.math.BigDecimal;

public class TransactionDetail {

	private long txid;
	private String timestmp;
	private String transtyp;
	private BigDecimal amount;
	private long reftxid;
	private long accid;
	private BigDecimal balance;

	public TransactionDetail() {
	}

	public TransactionDetail(long txid, String ts, String trantype, BigDecimal amount, long reftxid, long accid) {
		this.accid = accid;
		this.timestmp = ts;
		this.transtyp = trantype;
		this.txid = txid;
		this.amount = amount;
		this.reftxid = reftxid;
	}

	public long getTxid() {
		return txid;
	}

	public void setTxid(long txid) {
		this.txid = txid;
	}

	public String getTimestmp() {
		return timestmp;
	}

	public void setTimestmp(String timestmp) {
		this.timestmp = timestmp;
	}

	public String getTranstyp() {
		return String.valueOf(transtyp);
	}

	public void setTranstyp(String transtyp) {
		this.transtyp = transtyp;
	}

	public BigDecimal getAmount() {
		return amount;
	}

	public void setAmount(BigDecimal amount) {
		this.amount = amount;
	}

	public long getReftxid() {
		return reftxid;
	}

	public void setReftxid(long reftxid) {
		this.reftxid = reftxid;
	}

	public long getAccid() {
		return accid;
	}

	public void setAccid(long accid) {
		this.accid = accid;
	}

	public BigDecimal getBalance() {
		return balance;
	}

	public void setBalance(BigDecimal balance) {
		this.balance = balance;
	}

}
