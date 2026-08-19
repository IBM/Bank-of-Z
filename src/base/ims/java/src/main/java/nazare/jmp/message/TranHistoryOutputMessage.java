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
package nazare.jmp.message;

import com.ibm.ims.application.IMSFieldMessage;
import com.ibm.ims.base.DLITypeInfo;

public class TranHistoryOutputMessage extends IMSFieldMessage {
	private static final long serialVersionUID = 23432884;

	static DLITypeInfo[] fieldInfo = {

			new DLITypeInfo("MSG-OUT", DLITypeInfo.CHAR, 1, 32), new DLITypeInfo("TOTAL-TX", DLITypeInfo.INTEGER, 33, 4),
			new DLITypeInfo("TX-DETAIL", DLITypeInfo.BINARY, 37, 4200) // up to 50 records * 84 = 4200 bytes

	};

	public TranHistoryOutputMessage() {
		super(fieldInfo, 4236, false);
	}

}
