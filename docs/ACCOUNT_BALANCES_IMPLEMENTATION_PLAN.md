# Account Balances Implementation Plan

## Overview
This document outlines the implementation plan for enhancing the customer details page to display account information with lazy-loaded balance data.

## Current State Analysis

### Working Components ✅
1. **`/customers/{customerId}` API** - Fully functional
   - COBOL: `INQCUST.cbl`
   - Copybook: `INQCUSTZ.cpy`
   - API mappings: Complete and tested

2. **`/customers/{customerId}/accounts` API** - Partially functional
   - COBOL: `INQACCCU.cbl` 
   - Copybook: `INQACCCZ.cpy`
   - API mappings: Exist but need validation
   - Returns: Account list with basic info (accountId, accountType, currency, status)

3. **`/accounts/{accountId}/balances` API** - Needs fixes
   - COBOL: `INQACC.cbl`
   - Copybook: `INQACC-COMMAREA` (INQACC.cpy)
   - API mappings: Exist but incorrectly structured
   - Issue: Response mapping uses wrong field for `balanceType` and wraps single balance in array

### Data Flow Requirements

```
User Input: Customer ID
     ↓
1. GET /customers/{customerId}
     ↓
   Display customer info
     ↓
2. GET /customers/{customerId}/accounts
     ↓
   Display accounts table
     ↓
3. For each account:
   GET /accounts/{accountId}/balances (lazy load)
     ↓
   Update table row with balance info
```

## Implementation Tasks

### Phase 1: API Layer Fixes

#### Task 1.1: Fix `/accounts/{accountId}/balances` Response Mapping
**File**: `src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D%2Fbalances/get/response_200.yaml`

**Current Issues**:
- Line 15: Uses `INQACC-SUCCESS` for `balanceType` (wrong field)
- Line 10: Wraps single balance in unnecessary foreach array
- Missing proper balance type mapping

**Required Changes**:
```yaml
---
version: "1.2"
mappings:
- body:
    mappings:
    - balances:
        required: true
        nullable: false
        mappings:
        - balanceType:
            required: true
            nullable: false
            template: "AVAILABLE"
        - amount:
            required: true
            nullable: false
            expression: "$zosAssetResponse.commarea.\"INQACC-COMMAREA\".\"INQACC-AVAIL-BAL\""
        - currency:
            required: true
            nullable: false
            template: "GBP"
        - dateTime:
            required: true
            nullable: false
            expression: "$now()"
        - balanceType:
            required: true
            nullable: false
            template: "CURRENT"
        - amount:
            required: true
            nullable: false
            expression: "$zosAssetResponse.commarea.\"INQACC-COMMAREA\".\"INQACC-ACTUAL-BAL\""
        - currency:
            required: true
            nullable: false
            template: "GBP"
        - dateTime:
            required: true
            nullable: false
            expression: "$now()"
```

**Rationale**: 
- INQACC returns two balance fields: `INQACC-AVAIL-BAL` (available balance) and `INQACC-ACTUAL-BAL` (current/actual balance)
- Should return array with 2 balance objects: AVAILABLE and CURRENT
- Remove foreach wrapper since INQACC returns single account data, not array

#### Task 1.2: Validate `/customers/{customerId}/accounts` Response Mapping
**File**: `src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D%2Faccounts/get/response_200.yaml`

**Current State**: Looks correct but needs validation
- Uses foreach to iterate over `ACCOUNT-DETAILS` array
- Maps `COMM-ACCNO` to `accountId`
- Maps `COMM-ACC-TYPE` to `accountType`
- Hardcodes currency as "GBP" and status as "ACTIVE"

**Potential Enhancement**: Add more fields from INQACCCZ
```yaml
- accountNumber:
    required: false
    nullable: false
    template: "{{$item.\"COMM-ACCNO\"}}"
- sortCode:
    required: false
    nullable: false
    template: "{{$item.\"COMM-SCODE\"}}"
- openingDate:
    required: false
    nullable: false
    template: "{{$item.\"COMM-OPENED-YEAR\"}}-{{$item.\"COMM-OPENED-MONTH\"}}-{{$item.\"COMM-OPENED-DAY\"}}"
```

#### Task 1.3: Verify COBOL Programs
**Files to review**:
- `src/base/cics/cobol/INQACCCU.cbl` - Returns account list for customer
- `src/base/cics/cobol/INQACC.cbl` - Returns single account details with balances

**Verification Points**:
- ✅ INQACCCU correctly populates `COMM-AVAIL-BAL` and `COMM-ACTUAL-BAL` (lines 628-631)
- ✅ INQACC correctly populates `INQACC-AVAIL-BAL` and `INQACC-ACTUAL-BAL`
- ✅ Both programs handle DB2 queries correctly
- ✅ Error handling is in place

**Status**: COBOL programs appear correct, no changes needed

### Phase 2: Frontend Implementation

#### Task 2.1: Update Account Table Display
**File**: `src/frontend/customer-details.html`

**Current State** (lines 328-372):
- Basic table with accountId, accountNumber, sortCode, accountType, currency, status
- No balance columns

**Required Changes**:
```html
<table class="cds--data-table">
    <thead>
        <tr>
            <th>Account ID</th>
            <th>Account Number</th>
            <th>Sort Code</th>
            <th>Account Type</th>
            <th>Currency</th>
            <th>Available Balance</th>
            <th>Current Balance</th>
            <th>Status</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        <!-- Rows will be populated with balance loading indicators -->
    </tbody>
</table>
```

#### Task 2.2: Implement Lazy Loading Logic
**File**: `src/frontend/customer-details.html` (JavaScript section)

**New Function**: `loadAccountBalances(accountId, rowIndex)`
```javascript
async function loadAccountBalances(accountId, rowIndex) {
    const availBalCell = document.getElementById(`avail-bal-${rowIndex}`);
    const currentBalCell = document.getElementById(`current-bal-${rowIndex}`);
    
    // Show loading state
    availBalCell.innerHTML = '<cds-loading size="sm"></cds-loading>';
    currentBalCell.innerHTML = '<cds-loading size="sm"></cds-loading>';
    
    try {
        const response = await api.accounts.getAccountBalances(accountId);
        const balances = response.balances || [];
        
        // Find AVAILABLE and CURRENT balances
        const availBalance = balances.find(b => b.balanceType === 'AVAILABLE');
        const currentBalance = balances.find(b => b.balanceType === 'CURRENT');
        
        // Update cells with formatted values
        availBalCell.textContent = availBalance 
            ? formatCurrency(availBalance.amount, availBalance.currency)
            : 'N/A';
        currentBalCell.textContent = currentBalance 
            ? formatCurrency(currentBalance.amount, currentBalance.currency)
            : 'N/A';
    } catch (error) {
        console.error(`Error loading balances for account ${accountId}:`, error);
        availBalCell.textContent = 'Error';
        currentBalCell.textContent = 'Error';
    }
}
```

**Update**: `displayAccountsTable(accounts)` function
```javascript
function displayAccountsTable(accounts) {
    if (!accounts || accounts.length === 0) {
        document.getElementById('accounts-table').innerHTML = 
            '<p>No accounts found for this customer</p>';
        return;
    }
    
    let tableHTML = `
        <table class="cds--data-table">
            <thead>
                <tr>
                    <th>Account ID</th>
                    <th>Account Number</th>
                    <th>Sort Code</th>
                    <th>Account Type</th>
                    <th>Currency</th>
                    <th>Available Balance</th>
                    <th>Current Balance</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
    `;
    
    accounts.forEach((account, index) => {
        tableHTML += `
            <tr>
                <td>${account.accountId || 'N/A'}</td>
                <td>${account.accountNumber || 'N/A'}</td>
                <td>${account.sortCode || 'N/A'}</td>
                <td>${account.accountType || 'N/A'}</td>
                <td>${account.currency || 'N/A'}</td>
                <td id="avail-bal-${index}">
                    <cds-loading size="sm"></cds-loading>
                </td>
                <td id="current-bal-${index}">
                    <cds-loading size="sm"></cds-loading>
                </td>
                <td>${account.status || 'N/A'}</td>
                <td>
                    <a href="account-details.html?id=${account.accountId}">View</a>
                </td>
            </tr>
        `;
    });
    
    tableHTML += `
            </tbody>
        </table>
    `;
    
    document.getElementById('accounts-table').innerHTML = tableHTML;
    
    // Lazy load balances for each account
    accounts.forEach((account, index) => {
        if (account.accountId) {
            loadAccountBalances(account.accountId, index);
        }
    });
}
```

#### Task 2.3: Add Loading Component Import
**File**: `src/frontend/customer-details.html`

**Add to script imports** (around line 98):
```html
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/loading.min.js"></script>
```

### Phase 3: Error Handling & Edge Cases

#### Task 3.1: Handle API Errors
- Network failures
- Invalid account IDs
- Missing balance data
- Timeout scenarios

#### Task 3.2: Handle Edge Cases
- Customer with no accounts
- Accounts with missing balance data
- Very large number of accounts (>20)
- Concurrent balance loading

#### Task 3.3: Add User Feedback
- Loading indicators during balance fetch
- Error messages for failed balance loads
- Retry mechanism for failed requests

### Phase 4: Testing

#### Task 4.1: Unit Testing
- Test balance API response mapping
- Test frontend balance loading logic
- Test error handling

#### Task 4.2: Integration Testing
- Test complete flow: customer → accounts → balances
- Test with various customer IDs
- Test error scenarios

#### Task 4.3: Performance Testing
- Measure lazy loading performance
- Test with customers having many accounts
- Optimize if needed

### Phase 5: Documentation

#### Task 5.1: Update API Documentation
- Document balance response structure
- Add examples for balance API
- Update OpenAPI spec if needed

#### Task 5.2: Create User Guide
- How to view customer accounts
- Understanding balance types
- Troubleshooting common issues

## Data Structure Reference

### INQACCCU Response (Customer Accounts)
```
INQACCCZ
├── NUMBER-OF-ACCOUNTS (count)
├── CUSTOMER-NUMBER
├── COMM-SUCCESS (Y/N)
├── COMM-FAIL-CODE
└── ACCOUNT-DETAILS (array, max 20)
    ├── COMM-ACCNO (account number)
    ├── COMM-SCODE (sort code)
    ├── COMM-ACC-TYPE (account type)
    ├── COMM-AVAIL-BAL (available balance)
    └── COMM-ACTUAL-BAL (actual balance)
```

### INQACC Response (Single Account with Balances)
```
INQACC-COMMAREA
├── INQACC-ACCNO (account number)
├── INQACC-SCODE (sort code)
├── INQACC-ACC-TYPE (account type)
├── INQACC-AVAIL-BAL (available balance)
├── INQACC-ACTUAL-BAL (actual/current balance)
└── INQACC-SUCCESS (Y/N)
```

### OpenAPI Balance Schema
```json
{
  "balances": [
    {
      "balanceType": "AVAILABLE",
      "amount": 1234.56,
      "currency": "GBP",
      "dateTime": "2026-04-29T13:00:00Z"
    },
    {
      "balanceType": "CURRENT",
      "amount": 1200.00,
      "currency": "GBP",
      "dateTime": "2026-04-29T13:00:00Z"
    }
  ]
}
```

## Implementation Order

1. **Start with API fixes** (Phase 1) - Foundation must be solid
2. **Frontend table structure** (Phase 2.1) - Visual framework
3. **Lazy loading logic** (Phase 2.2-2.3) - Core functionality
4. **Error handling** (Phase 3) - Robustness
5. **Testing** (Phase 4) - Validation
6. **Documentation** (Phase 5) - Knowledge transfer

## Success Criteria

- ✅ Customer details page displays account list
- ✅ Each account row shows available and current balance
- ✅ Balances load asynchronously without blocking UI
- ✅ Loading indicators show during balance fetch
- ✅ Error states are handled gracefully
- ✅ Performance is acceptable (< 2s per balance load)
- ✅ All tests pass
- ✅ Documentation is complete

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| API mapping errors | High | Thorough testing with real data |
| COBOL field mismatches | High | Verify copybook structures match |
| Frontend performance issues | Medium | Implement request throttling |
| Balance data unavailable | Medium | Graceful error handling |
| Network timeouts | Low | Implement retry logic |

## Timeline Estimate

- Phase 1 (API fixes): 2-3 hours
- Phase 2 (Frontend): 3-4 hours
- Phase 3 (Error handling): 1-2 hours
- Phase 4 (Testing): 2-3 hours
- Phase 5 (Documentation): 1 hour

**Total**: 9-13 hours

## Next Steps

1. Review this plan with stakeholders
2. Get approval to proceed
3. Switch to Code mode to implement Phase 1
4. Iteratively implement remaining phases
5. Conduct thorough testing
6. Deploy to test environment
7. User acceptance testing
8. Production deployment

---

**Created**: 2026-04-29  
**Author**: Bob (Plan Mode)  
**Status**: Ready for Implementation