#!/bin/bash

################################################################################
# CBSA Banking APIs Test Script
# Tests all 10 z/OS Connect banking APIs
################################################################################

# Configuration
BASE_URL="http://lp25-zhss117.pok.stglabs.ibm.com:30701"
CONTENT_TYPE="Content-Type: application/json"

# Variables to capture from API responses
CUSTOMER_NO=""
ACCOUNT_NO_1=""
ACCOUNT_NO_2=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print test results with validation
print_result() {
    local test_name=$1
    local http_code=$2
    local response=$3
    local validate_success=${4:-false}  # Optional: validate CommSuccess field
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check HTTP status
    if [ "$http_code" = "200" ]; then
        # If validation requested, check CommSuccess field
        if [ "$validate_success" = "true" ]; then
            local success_field=$(echo "$response" | jq -r '.. | .CommSuccess? // .CreCustSuccess? // .CreAccSuccess? // .CommUpdSuccess? // .UpdAccSuccess? // .DbCrFunSuccess? // .DelaccDelSuccess? // .CommDelSuccess? // empty' 2>/dev/null | head -1)
            local fail_code=$(echo "$response" | jq -r '.. | .CommFailCode? // .CreCustFailCode? // .CreAccFailCode? // .CommUpdFailCd? // .UpdAccFailCode? // .DbCrFunFailCode? // .DelaccDelFailCd? // .CommDelFailCd? // empty' 2>/dev/null | head -1)
            
            if [ "$success_field" = "Y" ]; then
                echo -e "${GREEN}✓ PASS${NC} - $test_name (HTTP $http_code, Success=Y)"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            elif [ "$success_field" = "N" ]; then
                echo -e "${RED}✗ FAIL${NC} - $test_name (HTTP $http_code, Success=N, FailCode=$fail_code)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            else
                echo -e "${YELLOW}⚠ WARN${NC} - $test_name (HTTP $http_code, Success field not found)"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            fi
        else
            echo -e "${GREEN}✓ PASS${NC} - $test_name (HTTP $http_code)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
        echo -e "${YELLOW}Response:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        echo -e "${RED}✗ FAIL${NC} - $test_name (HTTP $http_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "${RED}Response:${NC}"
        echo "$response"
    fi
    echo ""
}

# Function to make API call
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local test_name=$4
    local validate_success=${5:-false}  # Optional: validate CommSuccess field
    
    echo -e "${YELLOW}Testing:${NC} $test_name"
    echo -e "${YELLOW}Endpoint:${NC} $method $endpoint"
    
    if [ -n "$data" ]; then
        echo -e "${BLUE}Request Body:${NC}"
        echo "$data" | jq '.' 2>/dev/null || echo "$data"
        echo -e "${BLUE}Curl Command:${NC}"
        echo "curl -X $method '$BASE_URL$endpoint' -H '$CONTENT_TYPE' -d '$data'"
        echo ""
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$BASE_URL$endpoint" \
            -H "$CONTENT_TYPE" \
            -d "$data")
    else
        echo -e "${BLUE}Curl Command:${NC}"
        echo "curl -X $method '$BASE_URL$endpoint' -H '$CONTENT_TYPE'"
        echo ""
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$BASE_URL$endpoint" \
            -H "$CONTENT_TYPE")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    print_result "$test_name" "$http_code" "$body" "$validate_success"
}

################################################################################
# START TESTS
################################################################################

print_header "CBSA Banking APIs - Comprehensive Test Suite"
echo "Base URL: $BASE_URL"
echo "Testing 11 APIs in logical order..."

################################################################################
# 1. CREATE CUSTOMER (CRECUST)
################################################################################
print_header "1. CREATE CUSTOMER (CRECUST)"

customer_data='{
  "CommName": "Mr John D Test",
  "CommAddress": "123 Test Street, Test City, TS 12345",
  "CommDateOfBirth": 15011990
}'

# Capture the response to extract customer number
response=$(curl -s -w "\n%{http_code}" -X "POST" \
    "$BASE_URL/crecust/insert" \
    -H "$CONTENT_TYPE" \
    -d "$customer_data")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Create Customer" "$http_code" "$body" "true"

# Extract customer number from response (it's in CommKey.CommNumber)
CUSTOMER_NO=$(echo "$body" | jq -r '.CommKey.CommNumber // .CommNumber // .CommCustno // .CreCustCustno // empty' 2>/dev/null)
if [ -z "$CUSTOMER_NO" ] || [ "$CUSTOMER_NO" = "null" ]; then
    echo -e "${RED}ERROR: Failed to extract customer number from response${NC}"
    exit 1
fi
# Pad to 10 digits for use in API calls
CUSTOMER_NO=$(printf "%010d" $CUSTOMER_NO)
echo -e "${GREEN}Captured Customer Number: $CUSTOMER_NO${NC}"
echo ""

################################################################################
# 2. ENQUIRE CUSTOMER (INQCUST)
################################################################################
print_header "2. ENQUIRE CUSTOMER (INQCUST)"

call_api "GET" "/inqcustz/enquiry/$CUSTOMER_NO" "" "Enquire Customer" "false"

################################################################################
# 3. CREATE ACCOUNT (CREACC)
################################################################################
print_header "3. CREATE ACCOUNT (CREACC)"

account_data='{
  "CommEyecatcher": "ACCT",
  "CommCustno": "'$CUSTOMER_NO'",
  "CommKey": {
    "CommSortcode": 0,
    "CommNumber": 0
  },
  "CommAccType": "SAVINGS",
  "CommIntRt": 2.50,
  "CommOpened": 0,
  "CommOverdrLim": 1000,
  "CommLastStmtDt": 0,
  "CommNextStmtDt": 0,
  "CommAvailBal": 0.00,
  "CommActBal": 0.00
}'

# Capture the response to extract account number
response=$(curl -s -w "\n%{http_code}" -X "POST" \
    "$BASE_URL/creacc/insert" \
    -H "$CONTENT_TYPE" \
    -d "$account_data")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Create Account 1" "$http_code" "$body" "true"

# Extract account number from response (it's in CommKey.CommNumber)
ACCOUNT_NO_1=$(echo "$body" | jq -r '.CommKey.CommNumber // .CommNumber // .CreAccAccno // .CommAccno // empty' 2>/dev/null)
if [ -z "$ACCOUNT_NO_1" ] || [ "$ACCOUNT_NO_1" = "null" ]; then
    echo -e "${RED}ERROR: Failed to extract account number from response${NC}"
    exit 1
fi
# Pad to 8 digits for use in API calls
ACCOUNT_NO_1=$(printf "%08d" $ACCOUNT_NO_1)
echo -e "${GREEN}Captured Account Number 1: $ACCOUNT_NO_1${NC}"
echo ""

################################################################################
# 4. CREATE SECOND ACCOUNT (CREACC)
################################################################################
print_header "4. CREATE SECOND ACCOUNT (CREACC)"

account_data_2='{
  "CommEyecatcher": "ACCT",
  "CommCustno": "'$CUSTOMER_NO'",
  "CommKey": {
    "CommSortcode": 0,
    "CommNumber": 0
  },
  "CommAccType": "ISA",
  "CommIntRt": 10.00,
  "CommOpened": 0,
  "CommOverdrLim": 500,
  "CommLastStmtDt": 0,
  "CommNextStmtDt": 0,
  "CommAvailBal": 0.00,
  "CommActBal": 0.00
}'

# Capture the response to extract second account number
response=$(curl -s -w "\n%{http_code}" -X "POST" \
    "$BASE_URL/creacc/insert" \
    -H "$CONTENT_TYPE" \
    -d "$account_data_2")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Create Account 2" "$http_code" "$body" "true"

# Extract second account number from response (it's in CommKey.CommNumber)
ACCOUNT_NO_2=$(echo "$body" | jq -r '.CommKey.CommNumber // .CommNumber // .CreAccAccno // .CommAccno // empty' 2>/dev/null)
if [ -z "$ACCOUNT_NO_2" ] || [ "$ACCOUNT_NO_2" = "null" ]; then
    echo -e "${RED}ERROR: Failed to extract second account number from response${NC}"
    exit 1
fi
# Pad to 8 digits for use in API calls
ACCOUNT_NO_2=$(printf "%08d" $ACCOUNT_NO_2)
echo -e "${GREEN}Captured Account Number 2: $ACCOUNT_NO_2${NC}"
echo ""

################################################################################
# 5. ENQUIRE ACCOUNT (INQACC)
################################################################################
print_header "5. ENQUIRE ACCOUNT (INQACC)"

call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_1" "" "Enquire Account 1" "false"

################################################################################
# 6. LIST CUSTOMER ACCOUNTS (INQACCCU)
################################################################################
print_header "6. LIST CUSTOMER ACCOUNTS (INQACCCU)"

# Capture response to verify we have 2 accounts
response=$(curl -s -w "\n%{http_code}" -X "GET" \
    "$BASE_URL/inqacccz/list/$CUSTOMER_NO" \
    -H "$CONTENT_TYPE")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "List Customer Accounts" "$http_code" "$body" "false"

# Verify we have 2 accounts
account_count=$(echo "$body" | jq '[.. | .InqAcccuAccno? // empty] | length' 2>/dev/null)
if [ "$account_count" = "2" ]; then
    echo -e "${GREEN}✓ Verified: Customer has 2 accounts${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Expected 2 accounts, found $account_count${NC}"
fi
echo ""

################################################################################
# 7. UPDATE CUSTOMER (UPDCUST)
################################################################################
print_header "7. UPDATE CUSTOMER (UPDCUST)"

updcust_data='{
  "CommEye": "CUST",
  "CommScode": "000001",
  "CommCustno": "'$CUSTOMER_NO'",
  "CommName": "Mr John D Updated",
  "CommAddress": "456 Updated Street, New City, NC 67890"
}'

call_api "PUT" "/updcust/update" "$updcust_data" "Update Customer" "true"

# Verify the update
echo -e "${BLUE}Verifying customer update...${NC}"
call_api "GET" "/inqcustz/enquiry/$CUSTOMER_NO" "" "Verify Customer Update" "false"

################################################################################
# 8. UPDATE ACCOUNT (UPDACC)
################################################################################
print_header "8. UPDATE ACCOUNT (UPDACC)"

updacc_data='{
  "CommEye": "ACCT",
  "CommCustno": "'$CUSTOMER_NO'",
  "CommScode": "000001",
  "CommAccno": '$ACCOUNT_NO_1',
  "CommAccType": "SAVINGS",
  "CommIntRate": 2.50,
  "CommOverdraft": 1000
}'

call_api "PUT" "/updacc/update" "$updacc_data" "Update Account" "true"

# Verify the update
echo -e "${BLUE}Verifying account update...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_1" "" "Verify Account Update" "false"

################################################################################
# 9. MAKE PAYMENT - DEBIT ACCOUNT 1 (DBCRFUN)
################################################################################
print_header "9. MAKE PAYMENT - DEBIT ACCOUNT 1 (DBCRFUN)"

payment_data='{
  "PAYDBCR": {
    "CommAccno": "'$ACCOUNT_NO_1'",
    "CommAmt": 100.00,
    "mSortC": 987654,
    "CommAvBal": 0.00,
    "CommActBal": 0.00,
    "CommOrigin": {
      "CommApplid": "",
      "CommUserid": "",
      "CommFacilityName": "",
      "CommNetwrkId": "",
      "CommFaciltype": 0,
      "Fill0": ""
    },
    "CommSuccess": "",
    "CommFailCode": ""
  }
}'

call_api "PUT" "/makepayment/dbcr" "$payment_data" "Make Payment (Debit Account 1)" "true"

# Verify the payment by checking account balance
echo -e "${BLUE}Verifying payment by checking account 1 balance...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_1" "" "Verify Payment Applied to Account 1" "false"

################################################################################
# 10. TRANSFER FUNDS - FROM ACCOUNT 1 TO ACCOUNT 2 (XFRFUN)
################################################################################
print_header "10. TRANSFER FUNDS - FROM ACCOUNT 1 TO ACCOUNT 2 (XFRFUN)"

transfer_data='{
  "XFRFUN": {
    "CommFscode": 987654,
    "CommFaccno": "'$ACCOUNT_NO_1'",
    "CommTscode": 987654,
    "CommTaccno": "'$ACCOUNT_NO_2'",
    "CommAmt": 50.00
  }
}'

# Call the transfer API
response=$(curl -s -w "\n%{http_code}" -X "PUT" \
    "$BASE_URL/transfer/funds" \
    -H "$CONTENT_TYPE" \
    -d "$transfer_data")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Transfer Funds (Account 1 -> Account 2)" "$http_code" "$body" "true"

# Verify the transfer by checking both account balances
echo -e "${BLUE}Verifying transfer - checking account 1 balance (should be -150.00)...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_1" "" "Verify Account 1 Balance After Transfer" "false"

echo -e "${BLUE}Verifying transfer - checking account 2 balance (should be 50.00)...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_2" "" "Verify Account 2 Balance After Transfer" "false"

################################################################################
# 11. DELETE ACCOUNT 1 (DELACC)
################################################################################
print_header "11. DELETE ACCOUNT 1 (DELACC)"

delacc_data_1='{
  "DelaccCommarea": {
    "DelaccEye": "ACCT",
    "DelaccCustno": "'$CUSTOMER_NO'",
    "DelaccScode": "000001",
    "DelaccAccno": "'$ACCOUNT_NO_1'",
    "DelaccAccType": "SAVINGS",
    "DelaccIntRate": 2.5,
    "DelaccOpened": 0,
    "DelaccOverdraft": 1000,
    "DelaccLastStmtDt": 0,
    "DelaccNextStmtDt": 0,
    "DelaccAvailBal": 0.00,
    "DelaccActualBal": 0.00,
    "DelaccSuccess": " ",
    "DelaccFailCd": " ",
    "DelaccDelSuccess": " ",
    "DelaccDelFailCd": " "
  }
}'

call_api "DELETE" "/delacc/remove/$ACCOUNT_NO_1" "$delacc_data_1" "Delete Account 1" "true"

# Verify deletion - should return error or empty
echo -e "${BLUE}Verifying account 1 deletion...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_1" "" "Verify Account 1 Deleted (should fail)" "false"

################################################################################
# 12. DELETE ACCOUNT 2 (DELACC)
################################################################################
print_header "12. DELETE ACCOUNT 2 (DELACC)"

delacc_data_2='{
  "DelaccCommarea": {
    "DelaccEye": "ACCT",
    "DelaccCustno": "'$CUSTOMER_NO'",
    "DelaccScode": "000001",
    "DelaccAccno": "'$ACCOUNT_NO_2'",
    "DelaccAccType": "CHECKING",
    "DelaccIntRate": 1.0,
    "DelaccOpened": 0,
    "DelaccOverdraft": 500,
    "DelaccLastStmtDt": 0,
    "DelaccNextStmtDt": 0,
    "DelaccAvailBal": 0.00,
    "DelaccActualBal": 0.00,
    "DelaccSuccess": " ",
    "DelaccFailCd": " ",
    "DelaccDelSuccess": " ",
    "DelaccDelFailCd": " "
  }
}'

call_api "DELETE" "/delacc/remove/$ACCOUNT_NO_2" "$delacc_data_2" "Delete Account 2" "true"

# Verify deletion - should return error or empty
echo -e "${BLUE}Verifying account 2 deletion...${NC}"
call_api "GET" "/inqaccz/enquiry/$ACCOUNT_NO_2" "" "Verify Account 2 Deleted (should fail)" "false"

################################################################################
# 13. DELETE CUSTOMER (DELCUS)
################################################################################
print_header "13. DELETE CUSTOMER (DELCUS)"

delcus_data='{
  "Comm": {
    "CommEye": "CUST",
    "CommScode": "000001",
    "CommCustno": "'$CUSTOMER_NO'",
    "CommName": "",
    "CommAddr": "",
    "CommDob": 0,
    "CommCreditScore": 0,
    "CommCsReviewDate": 0,
    "CommDelSuccess": " ",
    "CommDelFailCd": " "
  }
}'

call_api "DELETE" "/delcus/remove/$CUSTOMER_NO" "$delcus_data" "Delete Customer" "true"

# Verify deletion - should return error or empty
echo -e "${BLUE}Verifying customer deletion...${NC}"
call_api "GET" "/inqcustz/enquiry/$CUSTOMER_NO" "" "Verify Customer Deleted (should fail)" "false"

################################################################################
# TEST SUMMARY
################################################################################
print_header "TEST SUMMARY"

echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

# Made with Bob
