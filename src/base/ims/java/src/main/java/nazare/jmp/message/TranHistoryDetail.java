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
package nazare.jmp.message;

import com.ibm.ims.application.IMSFieldMessage;
import com.ibm.ims.base.DLITypeInfo;

public class TranHistoryDetail extends IMSFieldMessage {
	private static final long serialVersionUID = 23432884;

	static DLITypeInfo[] fieldInfo = {

			new DLITypeInfo("TXID", DLITypeInfo.BIGINT, 1, 8), new DLITypeInfo("TIMESTMP", DLITypeInfo.CHAR, 9, 23),
			new DLITypeInfo("TRANSTYP", DLITypeInfo.CHAR, 32, 1), new DLITypeInfo("AMOUNT", DLITypeInfo.CHAR, 33, 18),
			new DLITypeInfo("REFTXID", DLITypeInfo.BIGINT, 51, 8), new DLITypeInfo("ACCID", DLITypeInfo.BIGINT, 59, 8),
			new DLITypeInfo("BALANCE", DLITypeInfo.CHAR, 67, 18)

	};

	public TranHistoryDetail() {
		super(fieldInfo, 84, false);
	}

}
