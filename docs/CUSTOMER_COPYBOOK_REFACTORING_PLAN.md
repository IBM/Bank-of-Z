# Customer Copybook Refactoring Plan

## Executive Summary

This document outlines the comprehensive plan to refactor and standardize customer data structures across the Bank of Z CICS application. The refactoring addresses inconsistencies in copybook structures, eliminates unnecessary REDEFINES clauses, and ensures all customer-related copybooks follow a consistent pattern.

## Current Issues Identified

### 1. CUSTOMER.cpy Issues
- **Unnecessary REDEFINES**: Uses REDEFINES for DOB (lines 17-20) and CS-REVIEW-DATE (lines 40-44)
- **Duplicate CREATED-DATE**: CUSTOMER-CREATED-DATE appears twice (lines 33-37)
- **Inconsistent Structure**: Lacks grouping for NAME fields while ADDRESS is properly grouped
- **Missing PIC 9(8) parent**: DOB and dates use REDEFINES instead of nested structure

### 2. INQCUSTZ.cpy Issues
- **Flat ADDRESS Structure**: Unlike INQCUST.cpy, address fields are not grouped under INQCUST-ADDR
- **Inconsistent with INQCUST.cpy**: Different structure for same data

### 3. UPDCUST.cpy Issues
- **Uses REDEFINES**: For DOB (lines 14-17) and CS-REVIEW-DATE (lines 29-32)
- **No ADDRESS grouping**: Address fields are flat
- **Missing CREATED-DATE grouping**: Uses flat PIC 9(8) with REDEFINES

### 4. CRECUST.cpy Issues
- **Uses REDEFINES**: For DOB (lines 15-18) and CS-REVIEW-DATE (lines 30-33)
- **No ADDRESS grouping**: Address fields are flat
- **Inconsistent naming**: Uses COMM-DATE-OF-BIRTH vs CUSTOMER-DATE-OF-BIRTH

### 5. DELCUS.cpy Issues
- **Uses REDEFINES**: For DOB (lines 14-17), CREATED-DATE (lines 27-30), and CS-REVIEW-DATE (lines 33-36)
- **No ADDRESS grouping**: Address fields are flat

### 6. Program Issues
- **BANKDATA.cbl**: POSTCODE and COUNTRY fields exist but POSTCODE is not populated (line 569 only sets COUNTRY)
- **Multiple programs**: Reference individual date components using REDEFINES groups
- **Inconsistent field access**: Some use qualified names, others don't

### 7. API Mapping Issues
- **response_200.yaml**: Currently maps to flat INQCUSTZ structure
- **Missing nested structure**: API should reflect proper grouping per OpenAPI spec

## Proposed Standardized Structure

### New CUSTOMER.cpy Structure

```cobol
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
           03 CUSTOMER-RECORD.
              05 CUSTOMER-EYECATCHER                 PIC X(4).
                 88 CUSTOMER-EYECATCHER-VALUE        VALUE 'CUST'.
              05 CUSTOMER-KEY.
                 07 CUSTOMER-SORTCODE                PIC 9(6) DISPLAY.
                 07 CUSTOMER-NUMBER                  PIC 9(10) DISPLAY.
              05 CUSTOMER-NAME.
                 07 CUSTOMER-TITLE                   PIC X(10).
                 07 CUSTOMER-FIRST-NAME              PIC X(50).
                 07 CUSTOMER-LAST-NAME               PIC X(50).
              05 CUSTOMER-DOB.
                 07 CUSTOMER-DOB-DAY                 PIC 99.
                 07 CUSTOMER-DOB-MONTH               PIC 99.
                 07 CUSTOMER-DOB-YEAR                PIC 9999.
              05 CUSTOMER-EMAIL                      PIC X(100).
              05 CUSTOMER-PHONE                      PIC X(20).
              05 CUSTOMER-ADDRESS.
                 07 CUSTOMER-ADDR-LINE1              PIC X(50).
                 07 CUSTOMER-ADDR-LINE2              PIC X(50).
                 07 CUSTOMER-CITY                    PIC X(50).
                 07 CUSTOMER-POSTCODE                PIC X(10).
                 07 CUSTOMER-COUNTRY                 PIC X(50).
              05 CUSTOMER-STATUS                     PIC X(10).
                 88 CUSTOMER-STATUS-ACTIVE           VALUE 'ACTIVE'.
                 88 CUSTOMER-STATUS-INACTIVE         VALUE 'INACTIVE'.
                 88 CUSTOMER-STATUS-SUSPENDED        VALUE 'SUSPENDED'.
              05 CUSTOMER-CREATED-DATE.
                 07 CUSTOMER-CREATED-DAY             PIC 99.
                 07 CUSTOMER-CREATED-MONTH           PIC 99.
                 07 CUSTOMER-CREATED-YEAR            PIC 9999.
              05 CUSTOMER-CREDIT-SCORE               PIC 999.
              05 CUSTOMER-CS-REVIEW-DATE.
                 07 CUSTOMER-CS-REVIEW-DAY           PIC 99.
                 07 CUSTOMER-CS-REVIEW-MONTH         PIC 99.
                 07 CUSTOMER-CS-REVIEW-YEAR          PIC 9999.
```

**Key Changes:**
- Added `CUSTOMER-NAME` grouping for title, first name, and last name
- Removed all REDEFINES - use direct nested structure for dates
- Removed duplicate CUSTOMER-CREATED-DATE declaration
- Consistent nested structure for all date fields (DOB, CREATED-DATE, CS-REVIEW-DATE)
- ADDRESS already properly grouped - maintained as-is

### Benefits of New Structure

1. **No REDEFINES needed**: Direct access to date components
2. **Consistent grouping**: NAME, DOB, ADDRESS, CREATED-DATE, CS-REVIEW-DATE all grouped
3. **Clearer intent**: Structure shows logical relationships
4. **Easier maintenance**: Single source of truth for field organization
5. **API-friendly**: Nested structure maps naturally to JSON

## Implementation Plan

### Phase 1: Copybook Updates (Core Structure)

#### 1.1 Update CUSTOMER.cpy
- Remove REDEFINES for DOB (lines 17-20)
- Remove duplicate CREATED-DATE (lines 33-37)
- Remove REDEFINES for CS-REVIEW-DATE (lines 40-44)
- Add CUSTOMER-NAME grouping
- Restructure DOB, CREATED-DATE, CS-REVIEW-DATE as nested groups

#### 1.2 Update INQCUST.cpy
- Add INQCUST-NAME grouping
- Restructure INQCUST-DOB as nested group (already done, keep as-is)
- Restructure INQCUST-CREATED-DATE as nested group (already done, keep as-is)
- Restructure INQCUST-CS-REVIEW-DT as nested group (already done, keep as-is)
- Maintain INQCUST-ADDR grouping (already correct)

#### 1.3 Update INQCUSTZ.cpy
- Add INQCUST-NAME grouping
- Add INQCUST-ADDR grouping (currently flat)
- Restructure date fields to match INQCUST.cpy
- Ensure consistency with INQCUST.cpy structure

#### 1.4 Update UPDCUST.cpy
- Add COMM-NAME grouping
- Remove REDEFINES for COMM-DOB (lines 14-17)
- Add COMM-ADDR grouping
- Remove REDEFINES for COMM-CS-REVIEW-DATE (lines 29-32)
- Add COMM-CREATED-DATE grouping

#### 1.5 Update CRECUST.cpy
- Add COMM-NAME grouping
- Remove REDEFINES for COMM-DATE-OF-BIRTH (lines 15-18)
- Add COMM-ADDR grouping
- Remove REDEFINES for COMM-CS-REVIEW-DATE (lines 30-33)
- Add COMM-CREATED-DATE grouping
- Rename COMM-DATE-OF-BIRTH to COMM-DOB for consistency

#### 1.6 Update DELCUS.cpy
- Add COMM-NAME grouping
- Remove REDEFINES for COMM-DOB (lines 14-17)
- Add COMM-ADDR grouping
- Remove REDEFINES for COMM-CREATED-DATE (lines 27-30)
- Remove REDEFINES for COMM-CS-REVIEW-DATE (lines 33-36)

### Phase 2: COBOL Program Updates

#### 2.1 Update INQCUST.cbl
**Changes Required:**
- Line 270-275: Update field references to use CUSTOMER-NAME grouping
- Line 276-280: Update DOB field references (remove REDEFINES usage)
- Line 282-291: Update ADDRESS field references to use proper grouping
- Line 294-295: Update CREATED-DATE field references
- Line 381-395: Update all MOVE statements to use new nested structure
- Line 352-364: Verify DB2 SELECT statement field names
- Line 712-724: Verify DB2 SELECT statement field names

**Specific Changes:**
```cobol
MOVE CUSTOMER-TITLE OF CUSTOMER-NAME OF OUTPUT-DATA TO INQCUST-TITLE
MOVE CUSTOMER-FIRST-NAME OF CUSTOMER-NAME OF OUTPUT-DATA TO INQCUST-FIRST-NAME
MOVE CUSTOMER-LAST-NAME OF CUSTOMER-NAME OF OUTPUT-DATA TO INQCUST-LAST-NAME
MOVE CUSTOMER-DOB-DAY OF CUSTOMER-DOB OF OUTPUT-DATA TO INQCUST-DOB-DD
```

#### 2.2 Update UPDCUST.cbl
**Changes Required:**
- Line 317-321: Update name field references to use COMM-NAME grouping
- Line 331-337: Update address field references to use COMM-ADDR grouping
- Line 381-395: Update all MOVE statements to use new nested structure
- Line 348-358: Update DB2 UPDATE statement field names
- Remove references to REDEFINES groups (COMM-DOB-GROUP, COMM-CS-GROUP)

#### 2.3 Update CRECUST.cbl
**Changes Required:**
- Line 1163-1165: Update name field references
- Line 1166: Change COMM-DATE-OF-BIRTH to COMM-DOB
- Line 1169-1174: Update address field references to use COMM-ADDR grouping
- Line 1175: Update CREATED-DATE reference
- Line 1185-1196: Update all HV- variable assignments
- Line 1203-1207: Update DISPLAY statements
- Line 1244-1256: Verify DB2 INSERT statement field names
- Line 1284-1287: Update STRING statement for customer name

#### 2.4 Update DELCUS.cbl
**Changes Required:**
- Line 564-574: Update all MOVE statements to use new nested structure
- Line 577-580: Update STRING statement for customer name
- Line 583-588: Update STRING statement for customer address
- Line 594-595: Update DOB field references
- Line 463-475: Verify DB2 SELECT statement field names
- Remove references to REDEFINES groups

#### 2.5 Update BANKDATA.cbl
**Changes Required:**
- Line 535-555: Update field initialization to use new nested structure
- Line 540-544: Update address field references to use CUSTOMER-ADDRESS grouping
- Line 547-553: Update name field references to use CUSTOMER-NAME grouping
- Line 571-576: Update DOB field references to use CUSTOMER-DOB grouping
- **CRITICAL**: Line 569 - Add POSTCODE population (currently missing)
- Line 616-626: Update all HV- variable assignments
- Line 632-635: Update DOB calculation
- Line 673-685: Verify DB2 INSERT statement field names
- Line 1082-1087: Update DOB DISPLAY statements
- Line 1097-1106: Update DOB comparison logic

**Specific Fix for POSTCODE:**
```cobol
COMPUTE WS-POSTCODE-NUM = ((9999 - 1000) * FUNCTION RANDOM) + 1000
STRING 'SW' DELIMITED BY SIZE
       WS-POSTCODE-NUM DELIMITED BY SIZE
       INTO CUSTOMER-POSTCODE OF CUSTOMER-ADDRESS
```

#### 2.6 Update INQACCCU.cbl
**Changes Required:**
- Review usage of CUSTOMER-AREA and INQCUST-COMMAREA
- Update any field references to use new nested structure

#### 2.7 Update BNK1DCS.cbl
**Changes Required:**
- Review usage of INQCUST-COMMAREA, DELCUS-COMMAREA, UPDCUST-COMMAREA
- Update any field references to use new nested structure

#### 2.8 Update CREACC.cbl
**Changes Required:**
- Review usage of OUTPUTC-DATA and INQCUST-COMMAREA
- Update any field references to use new nested structure

### Phase 3: BMS Map Updates

#### 3.1 Review BNK1CAM.bms
- Verify if customer name fields are displayed
- Update field mappings if needed to use new nested structure

#### 3.2 Review Other BMS Maps
- Check BNK1CCM.bms, BNK1CDM.bms, BNK1DAM.bms, BNK1DCM.bms, BNK1UAM.bms
- Update any customer field references

### Phase 4: z/OS Connect API Updates

#### 4.1 Update response_200.yaml
**Current Mapping (uses flat INQCUSTZ):**
```yaml
- title:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-TITLE\"}}"
- firstName:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-FIRST-NAME\"}}"
```

**New Mapping (uses nested structure):**
```yaml
- title:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-NAME\".\"INQCUST-TITLE\"}}"
- firstName:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-NAME\".\"INQCUST-FIRST-NAME\"}}"
- lastName:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-NAME\".\"INQCUST-LAST-NAME\"}}"
- dateOfBirth:
    template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-DOB\".\"INQCUST-DOB-YYYY\"}}-{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-DOB\".\"INQCUST-DOB-MM\"}}-{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-DOB\".\"INQCUST-DOB-DD\"}}"
- address:
    mappings:
      - addressLine1:
          template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-ADDR\".\"INQCUST-ADDR-LINE1\"}}"
      - addressLine2:
          template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-ADDR\".\"INQCUST-ADDR-LINE2\"}}"
      - city:
          template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-ADDR\".\"INQCUST-CITY\"}}"
      - postalCode:
          template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-ADDR\".\"INQCUST-POSTCODE\"}}"
      - country:
          template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-ADDR\".\"INQCUST-COUNTRY\"}}"
```

#### 4.2 Update INQACCCZ.cpy if needed
- Review if customer data structure is referenced
- Update if necessary to match new structure

#### 4.3 Regenerate z/OS Connect Assets
- After copybook changes, regenerate DAI files
- Update generated copybooks in `src/api/src/main/zosAssets/*/providerFiles/gen/`

### Phase 5: Database Verification

#### 5.1 Verify DB2 Table Structure
- Confirm CUSTOMER table column names match new field names
- Expected columns:
  - CUSTOMER_NUMBER
  - CUSTOMER_TITLE
  - CUSTOMER_FIRST_NAME
  - CUSTOMER_LAST_NAME
  - CUSTOMER_DOB (or CUSTOMER_DATE_OF_BIRTH)
  - CUSTOMER_EMAIL
  - CUSTOMER_PHONE
  - CUSTOMER_ADDR_LINE1
  - CUSTOMER_ADDR_LINE2
  - CUSTOMER_CITY
  - CUSTOMER_POSTCODE
  - CUSTOMER_COUNTRY
  - CUSTOMER_STATUS
  - CUSTOMER_CREATE_DATE (or CUSTOMER_CREATED_DATE)
  - CUSTOMER_CREDIT_SCORE
  - CUSTOMER_CS_REVIEW_DATE

#### 5.2 Update SQL Statements
- Verify all SELECT, INSERT, UPDATE statements use correct column names
- Ensure date fields are handled correctly (may need DECIMAL to component conversion)

### Phase 6: Testing Strategy

#### 6.1 Unit Testing
- Test each updated COBOL program individually
- Verify field access works correctly with new nested structure
- Test date field conversions

#### 6.2 Integration Testing
- Test INQCUST transaction end-to-end
- Test UPDCUST transaction end-to-end
- Test CRECUST transaction end-to-end
- Test DELCUS transaction end-to-end
- Test account creation with customer inquiry (CREACC)

#### 6.3 API Testing
- Test GET /customers/{customerId} endpoint
- Verify JSON response matches OpenAPI spec
- Verify all nested fields are populated correctly
- Test that POSTCODE and COUNTRY are now returned

#### 6.4 BMS Testing
- Test all customer-related screens
- Verify data displays correctly
- Test data entry and updates

#### 6.5 Regression Testing
- Run existing test suites
- Verify no functionality is broken
- Test edge cases (empty fields, special characters, etc.)

### Phase 7: Documentation

#### 7.1 Update Technical Documentation
- Document new copybook structure
- Update field reference guide
- Document migration from old to new structure

#### 7.2 Create Migration Guide
- Document breaking changes
- Provide before/after examples
- Include troubleshooting guide

#### 7.3 Update API Documentation
- Ensure OpenAPI spec reflects actual implementation
- Update example responses
- Document nested structure

## Risk Assessment

### High Risk Items
1. **DB2 Field Name Mismatches**: If DB2 columns don't match COBOL field names
2. **Date Conversion Logic**: Changing from REDEFINES to nested may affect calculations
3. **API Breaking Changes**: Nested structure changes JSON response format

### Medium Risk Items
1. **BMS Map Compatibility**: Maps may need recompilation
2. **POSTCODE Population**: Adding new logic may have side effects
3. **Multiple Program Updates**: Coordination required across many files

### Low Risk Items
1. **Copybook Structure**: Well-defined changes with clear benefits
2. **Consistency Improvements**: Reduces future maintenance burden

## Rollback Plan

If issues are encountered:
1. Keep backup copies of all original copybooks
2. Version control all changes
3. Test in development environment first
4. Have rollback scripts ready
5. Document all changes for easy reversal

## Success Criteria

1. All copybooks follow consistent nested structure
2. No REDEFINES used for date fields
3. All COBOL programs compile successfully
4. All transactions function correctly
5. API returns properly nested JSON
6. POSTCODE and COUNTRY fields are populated
7. All tests pass
8. No regression in functionality

## Timeline Estimate

- Phase 1 (Copybooks): 2-3 hours
- Phase 2 (COBOL Programs): 6-8 hours
- Phase 3 (BMS Maps): 1-2 hours
- Phase 4 (API): 2-3 hours
- Phase 5 (Database): 1-2 hours
- Phase 6 (Testing): 4-6 hours
- Phase 7 (Documentation): 2-3 hours

**Total Estimated Time**: 18-27 hours

## Conclusion

This refactoring will significantly improve the maintainability and consistency of the customer data structures across the Bank of Z application. By eliminating REDEFINES and standardizing the nested structure, we create a more intuitive and API-friendly data model that aligns with modern development practices while maintaining COBOL best practices.