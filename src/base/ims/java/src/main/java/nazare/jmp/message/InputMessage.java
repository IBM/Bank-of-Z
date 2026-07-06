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

public class InputMessage extends IMSFieldMessage {

	private static final long serialVersionUID = 1L;
	static DLITypeInfo[] fieldInfo = {
			// ACTION for our example can be 'get ' or 'put '
			new DLITypeInfo("accountNumber", DLITypeInfo.CHAR, 1, 18) };

	/**
	 * Required no arguments constructor
	 */
	public InputMessage() {
		super(fieldInfo, 18, false);
	}

}
