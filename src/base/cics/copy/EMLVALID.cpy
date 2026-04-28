      ******************************************************************
      *                                                                *
      *  Email validation commarea                                     *
      *                                                                *
      ******************************************************************
          03 EMLVALID-EMAIL                 PIC X(60).
          03 EMLVALID-REQUIRED              PIC X.
             88 EMLVALID-EMAIL-REQUIRED     VALUE 'Y'.
             88 EMLVALID-EMAIL-OPTIONAL     VALUE 'N'.
          03 EMLVALID-RESULT                PIC X.
             88 EMLVALID-EMAIL-VALID        VALUE 'Y'.
             88 EMLVALID-EMAIL-INVALID      VALUE 'N'.
          03 EMLVALID-REASON                PIC X.
             88 EMLVALID-MISSING-EMAIL      VALUE 'R'.
             88 EMLVALID-BAD-FORMAT         VALUE 'F'.
