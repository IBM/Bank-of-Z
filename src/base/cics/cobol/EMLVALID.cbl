      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. EMLVALID.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-EMAIL-LENGTH              PIC 9(3) VALUE 0.
       01 WS-POSITION                  PIC 9(3) VALUE 0.
       01 WS-AT-POSITION               PIC 9(3) VALUE 0.
       01 WS-LAST-DOT-POSITION         PIC 9(3) VALUE 0.
       01 WS-FIRST-DOT-AFTER-AT        PIC 9(3) VALUE 0.
       01 WS-AT-COUNT                  PIC 9(2) VALUE 0.
       01 WS-DOT-AFTER-AT-COUNT        PIC 9(2) VALUE 0.
       01 WS-CURRENT-CHAR              PIC X VALUE SPACE.
       01 WS-PREV-CHAR                 PIC X VALUE SPACE.
       01 WS-LOCAL-LENGTH              PIC 9(3) VALUE 0.
       01 WS-DOMAIN-LENGTH             PIC 9(3) VALUE 0.
       01 WS-TLD-LENGTH                PIC 9(3) VALUE 0.
       01 WS-EMAIL-OK                  PIC X VALUE 'Y'.
          88 EMAIL-OK                  VALUE 'Y'.
          88 EMAIL-NOT-OK              VALUE 'N'.

       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY EMLVALID.

       PROCEDURE DIVISION USING DFHCOMMAREA.
       MAINLINE SECTION.
       ML010.

           PERFORM INITIALIZE-VALIDATION.
           PERFORM CALCULATE-EMAIL-LENGTH.

           IF WS-EMAIL-LENGTH = 0
              IF EMLVALID-EMAIL-REQUIRED
                 PERFORM MARK-MISSING-EMAIL
              END-IF
           ELSE
              PERFORM VALIDATE-EMAIL-FORMAT
              IF EMAIL-OK
                 SET EMLVALID-EMAIL-VALID TO TRUE
              ELSE
                 PERFORM MARK-BAD-FORMAT
              END-IF
           END-IF.

           EXEC CICS RETURN
           END-EXEC.

       ML999.
           EXIT.


       INITIALIZE-VALIDATION SECTION.
       IV010.

           INSPECT EMLVALID-EMAIL REPLACING ALL LOW-VALUE BY SPACE.
           SET EMLVALID-EMAIL-VALID TO TRUE.
           MOVE SPACE TO EMLVALID-REASON.
           MOVE ZERO TO WS-EMAIL-LENGTH
                        WS-POSITION
                        WS-AT-POSITION
                        WS-LAST-DOT-POSITION
                        WS-FIRST-DOT-AFTER-AT
                        WS-AT-COUNT
                        WS-DOT-AFTER-AT-COUNT
                        WS-LOCAL-LENGTH
                        WS-DOMAIN-LENGTH
                        WS-TLD-LENGTH.
           MOVE SPACE TO WS-CURRENT-CHAR
                         WS-PREV-CHAR.
           SET EMAIL-OK TO TRUE.

       IV999.
           EXIT.


       CALCULATE-EMAIL-LENGTH SECTION.
       CEL010.

           PERFORM VARYING WS-POSITION FROM 60 BY -1
              UNTIL WS-POSITION < 1
                 OR WS-EMAIL-LENGTH > 0
              IF EMLVALID-EMAIL(WS-POSITION:1) NOT = SPACE
                 MOVE WS-POSITION TO WS-EMAIL-LENGTH
              END-IF
           END-PERFORM.

       CEL999.
           EXIT.


       VALIDATE-EMAIL-FORMAT SECTION.
       VEF010.

           PERFORM CHECK-FIRST-LAST-CHARS.
           IF EMAIL-OK
              PERFORM SCAN-EMAIL-CHARACTERS
           END-IF.
           IF EMAIL-OK
              PERFORM VALIDATE-AT-SYMBOL
           END-IF.
           IF EMAIL-OK
              PERFORM VALIDATE-DOT-PLACEMENT
           END-IF.
           IF EMAIL-OK
              PERFORM VALIDATE-PART-LENGTHS
           END-IF.
           IF EMAIL-OK
              PERFORM VALIDATE-TLD-LENGTH
           END-IF.

       VEF999.
           EXIT.


       CHECK-FIRST-LAST-CHARS SECTION.
       CFLC010.

           MOVE EMLVALID-EMAIL(1:1) TO WS-CURRENT-CHAR.
           IF WS-CURRENT-CHAR = '@'
           OR WS-CURRENT-CHAR = '.'
              SET EMAIL-NOT-OK TO TRUE
           ELSE
              MOVE EMLVALID-EMAIL(WS-EMAIL-LENGTH:1)
                 TO WS-CURRENT-CHAR
              IF WS-CURRENT-CHAR = '@'
              OR WS-CURRENT-CHAR = '.'
                 SET EMAIL-NOT-OK TO TRUE
              END-IF
           END-IF.

       CFLC999.
           EXIT.


       SCAN-EMAIL-CHARACTERS SECTION.
       SEC010.

           MOVE SPACE TO WS-PREV-CHAR.

           PERFORM VARYING WS-POSITION FROM 1 BY 1
              UNTIL WS-POSITION > WS-EMAIL-LENGTH
                 OR EMAIL-NOT-OK
              MOVE EMLVALID-EMAIL(WS-POSITION:1)
                 TO WS-CURRENT-CHAR
              PERFORM CHECK-CHARACTER-VALIDITY
              IF EMAIL-OK
                 PERFORM CHECK-CONSECUTIVE-DOTS
              END-IF
              IF EMAIL-OK
                 PERFORM COUNT-SPECIAL-CHARS
              END-IF
              MOVE WS-CURRENT-CHAR TO WS-PREV-CHAR
           END-PERFORM.

       SEC999.
           EXIT.


       CHECK-CHARACTER-VALIDITY SECTION.
       CCV010.

           EVALUATE WS-CURRENT-CHAR
              WHEN '@'
              WHEN '.'
              WHEN '-'
                 CONTINUE
              WHEN 'A' THRU 'Z'
              WHEN 'a' THRU 'z'
              WHEN '0' THRU '9'
                 CONTINUE
              WHEN '_'
                 IF WS-AT-COUNT > 0
                    SET EMAIL-NOT-OK TO TRUE
                 END-IF
              WHEN OTHER
                 SET EMAIL-NOT-OK TO TRUE
           END-EVALUATE.

       CCV999.
           EXIT.


       CHECK-CONSECUTIVE-DOTS SECTION.
       CCD010.

           IF WS-CURRENT-CHAR = '.'
           AND WS-PREV-CHAR = '.'
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

       CCD999.
           EXIT.


       COUNT-SPECIAL-CHARS SECTION.
       CSC010.

           IF WS-CURRENT-CHAR = '@'
              ADD 1 TO WS-AT-COUNT
              MOVE WS-POSITION TO WS-AT-POSITION
           END-IF.

           IF WS-CURRENT-CHAR = '.'
              MOVE WS-POSITION TO WS-LAST-DOT-POSITION
              IF WS-AT-COUNT > 0
                 ADD 1 TO WS-DOT-AFTER-AT-COUNT
                 IF WS-FIRST-DOT-AFTER-AT = 0
                    MOVE WS-POSITION TO WS-FIRST-DOT-AFTER-AT
                 END-IF
              END-IF
           END-IF.

       CSC999.
           EXIT.


       VALIDATE-AT-SYMBOL SECTION.
       VAS010.

           IF WS-AT-COUNT NOT = 1
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

       VAS999.
           EXIT.


       VALIDATE-DOT-PLACEMENT SECTION.
       VDP010.

           IF WS-DOT-AFTER-AT-COUNT = 0
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

           IF WS-FIRST-DOT-AFTER-AT = WS-AT-POSITION + 1
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

       VDP999.
           EXIT.


       VALIDATE-PART-LENGTHS SECTION.
       VPL010.

           COMPUTE WS-LOCAL-LENGTH = WS-AT-POSITION - 1.
           COMPUTE WS-DOMAIN-LENGTH =
              WS-EMAIL-LENGTH - WS-AT-POSITION.

           IF WS-LOCAL-LENGTH = 0
           OR WS-DOMAIN-LENGTH = 0
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

       VPL999.
           EXIT.


       VALIDATE-TLD-LENGTH SECTION.
       VTL010.

           COMPUTE WS-TLD-LENGTH =
              WS-EMAIL-LENGTH - WS-LAST-DOT-POSITION.

           IF WS-TLD-LENGTH < 2
              SET EMAIL-NOT-OK TO TRUE
           END-IF.

       VTL999.
           EXIT.


       MARK-MISSING-EMAIL SECTION.
       MME010.

           SET EMLVALID-EMAIL-INVALID TO TRUE.
           SET EMLVALID-MISSING-EMAIL TO TRUE.

       MME999.
           EXIT.


       MARK-BAD-FORMAT SECTION.
       MBF010.

           SET EMLVALID-EMAIL-INVALID TO TRUE.
           SET EMLVALID-BAD-FORMAT TO TRUE.

       MBF999.
           EXIT.
