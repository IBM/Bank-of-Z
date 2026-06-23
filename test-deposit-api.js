/**
 * Deposit API Test Script
 * Tests the POST /accounts/{accountId}/deposit endpoint
 * 
 * Usage: node test-deposit-api.js
 */

const API_BASE_URL = 'http://localhost:9080';
const TEST_ACCOUNT_ID = '12345678';
const TEST_SORT_CODE = '987654';

// ANSI color codes for terminal output
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    bold: '\x1b[1m'
};

/**
 * Test case structure
 */
class TestCase {
    constructor(name, accountId, payload, expectedStatus, description) {
        this.name = name;
        this.accountId = accountId;
        this.payload = payload;
        this.expectedStatus = expectedStatus;
        this.description = description;
    }
}

/**
 * Make API request
 */
async function makeDepositRequest(accountId, payload) {
    const url = `${API_BASE_URL}/accounts/${accountId}/deposit`;
    
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                // Note: In production, add Authorization header
                // 'Authorization': 'Bearer YOUR_TOKEN'
            },
            body: JSON.stringify(payload)
        });

        const data = await response.text().then(text => {
            try {
                return JSON.parse(text);
            } catch {
                return text;
            }
        });

        return {
            status: response.status,
            statusText: response.statusText,
            data: data
        };
    } catch (error) {
        return {
            status: 0,
            statusText: 'Network Error',
            data: { error: error.message }
        };
    }
}

/**
 * Run a single test case
 */
async function runTest(testCase) {
    console.log(`\n${colors.cyan}${colors.bold}Test: ${testCase.name}${colors.reset}`);
    console.log(`${colors.blue}Description: ${testCase.description}${colors.reset}`);
    console.log(`Account ID: ${testCase.accountId}`);
    console.log(`Payload: ${JSON.stringify(testCase.payload, null, 2)}`);
    
    const result = await makeDepositRequest(testCase.accountId, testCase.payload);
    
    console.log(`\nResponse Status: ${result.status} ${result.statusText}`);
    console.log(`Response Body: ${JSON.stringify(result.data, null, 2)}`);
    
    const passed = result.status === testCase.expectedStatus;
    
    if (passed) {
        console.log(`${colors.green}${colors.bold}✓ PASSED${colors.reset} - Expected status ${testCase.expectedStatus}, got ${result.status}`);
    } else {
        console.log(`${colors.red}${colors.bold}✗ FAILED${colors.reset} - Expected status ${testCase.expectedStatus}, got ${result.status}`);
    }
    
    return { testCase, result, passed };
}

/**
 * Main test suite
 */
async function runTestSuite() {
    console.log(`${colors.bold}${colors.cyan}========================================`);
    console.log(`Deposit API Test Suite`);
    console.log(`========================================${colors.reset}\n`);
    console.log(`API Base URL: ${API_BASE_URL}`);
    console.log(`Test Account: ${TEST_ACCOUNT_ID}`);
    console.log(`Sort Code: ${TEST_SORT_CODE}\n`);

    const testCases = [
        new TestCase(
            'Valid Deposit - Standard Amount',
            TEST_ACCOUNT_ID,
            {
                amount: 100.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - standard amount'
            },
            201,
            'Test a valid deposit with a standard amount'
        ),
        
        new TestCase(
            'Valid Deposit - Minimum Amount',
            TEST_ACCOUNT_ID,
            {
                amount: 0.01,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - minimum amount'
            },
            201,
            'Test deposit with minimum allowed amount (0.01)'
        ),
        
        new TestCase(
            'Valid Deposit - Large Amount',
            TEST_ACCOUNT_ID,
            {
                amount: 10000.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - large amount'
            },
            201,
            'Test deposit with a large amount'
        ),
        
        new TestCase(
            'Valid Deposit - No Description',
            TEST_ACCOUNT_ID,
            {
                amount: 50.00,
                sortCode: TEST_SORT_CODE
            },
            201,
            'Test deposit without optional description field'
        ),
        
        new TestCase(
            'Invalid - Negative Amount',
            TEST_ACCOUNT_ID,
            {
                amount: -100.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - negative amount'
            },
            400,
            'Test that negative amounts are rejected'
        ),
        
        new TestCase(
            'Invalid - Zero Amount',
            TEST_ACCOUNT_ID,
            {
                amount: 0.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - zero amount'
            },
            400,
            'Test that zero amount is rejected'
        ),
        
        new TestCase(
            'Invalid - Missing Amount',
            TEST_ACCOUNT_ID,
            {
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - missing amount'
            },
            400,
            'Test that missing required amount field is rejected'
        ),
        
        new TestCase(
            'Invalid - Missing Sort Code',
            TEST_ACCOUNT_ID,
            {
                amount: 100.00,
                description: 'Test deposit - missing sort code'
            },
            400,
            'Test that missing required sortCode field is rejected'
        ),
        
        new TestCase(
            'Invalid - Invalid Sort Code Format',
            TEST_ACCOUNT_ID,
            {
                amount: 100.00,
                sortCode: '12345',  // Only 5 digits instead of 6
                description: 'Test deposit - invalid sort code'
            },
            400,
            'Test that invalid sort code format is rejected'
        ),
        
        new TestCase(
            'Invalid - Description Too Long',
            TEST_ACCOUNT_ID,
            {
                amount: 100.00,
                sortCode: TEST_SORT_CODE,
                description: 'A'.repeat(50)  // Max is 40 characters
            },
            400,
            'Test that description exceeding 40 characters is rejected'
        ),
        
        new TestCase(
            'Invalid - Non-existent Account',
            '99999999',
            {
                amount: 100.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - non-existent account'
            },
            404,
            'Test deposit to a non-existent account'
        ),
        
        new TestCase(
            'Invalid - Malformed Account ID',
            'INVALID',
            {
                amount: 100.00,
                sortCode: TEST_SORT_CODE,
                description: 'Test deposit - malformed account ID'
            },
            404,
            'Test deposit with malformed account ID'
        )
    ];

    const results = [];
    
    for (const testCase of testCases) {
        const result = await runTest(testCase);
        results.push(result);
        
        // Add delay between tests to avoid overwhelming the API
        await new Promise(resolve => setTimeout(resolve, 500));
    }

    // Print summary
    console.log(`\n${colors.bold}${colors.cyan}========================================`);
    console.log(`Test Summary`);
    console.log(`========================================${colors.reset}\n`);
    
    const passed = results.filter(r => r.passed).length;
    const failed = results.filter(r => !r.passed).length;
    const total = results.length;
    
    console.log(`Total Tests: ${total}`);
    console.log(`${colors.green}Passed: ${passed}${colors.reset}`);
    console.log(`${colors.red}Failed: ${failed}${colors.reset}`);
    console.log(`Success Rate: ${((passed / total) * 100).toFixed(1)}%\n`);
    
    if (failed > 0) {
        console.log(`${colors.red}${colors.bold}Failed Tests:${colors.reset}`);
        results.filter(r => !r.passed).forEach(r => {
            console.log(`  ${colors.red}✗${colors.reset} ${r.testCase.name}`);
            console.log(`    Expected: ${r.testCase.expectedStatus}, Got: ${r.result.status}`);
        });
        console.log();
    }
    
    // Exit with appropriate code
    process.exit(failed > 0 ? 1 : 0);
}

// Run the test suite
console.log(`${colors.yellow}Starting Deposit API Tests...${colors.reset}\n`);
runTestSuite().catch(error => {
    console.error(`${colors.red}${colors.bold}Fatal Error:${colors.reset}`, error);
    process.exit(1);
});

// Made with Bob
