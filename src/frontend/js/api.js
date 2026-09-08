/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Bank of Z - OpenBanking API Client

 * 
 * This is a zero-dependency API client using native fetch()
 * Based on: src/api/src/main/api/openapi.yaml
 */

import { config } from '../config.js';

/**
 * Base API configuration
 */
class ApiConfiguration {
    constructor() {
        this.baseUrl = config.api.baseUrl;
        this.defaultHeaders = {
            'Content-Type': 'application/json'
        };
    }
}

/**
 * Helper function to determine system type from customer ID
 * @param {string} customerId - Customer ID with prefix (C for CICS, I for IMS)
 * @returns {string} 'IMS' or 'CICS'
 */
function getSystemFromCustomerId(customerId) {
    if (!customerId) return 'CICS';
    const idStr = customerId.toString().toUpperCase();
    return idStr.startsWith('I') ? 'IMS' : 'CICS';
}

/**
 * Base API client with common request handling
 */
class BaseApi {
    constructor(configuration) {
        this.configuration = configuration;
    }

    /**
     * Execute HTTP request with error handling
     * @param {string} url - Request URL
     * @param {object} options - Fetch options
     * @returns {Promise<any>} Response data
     */
    async request(url, options = {}) {
        try {
            const response = await fetch(url, {
                headers: {
                    ...this.configuration.defaultHeaders,
                    ...options.headers
                },
                ...options
            });

            // Handle different response types
            const contentType = response.headers.get('content-type');
            let data;
            
            if (contentType && contentType.includes('application/json')) {
                data = await response.json();
            } else {
                data = await response.text();
            }

            if (!response.ok) {
                const error = new Error(data.message || `HTTP error! status: ${response.status}`);
                error.status = response.status;
                error.code = data.code;
                error.details = data.details;
                throw error;
            }

            return data;
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }
}

/**
 * Customer API operations
 * Tag: Customers
 */
class CustomersApi extends BaseApi {
    /**
     * Get customer information
     * GET /customers/{customerId} or /ims/customers/{customerId}
     * Routes based on explicit system parameter (from C/I prefix)
     * @param {string} customerId - Unique identifier for the customer (numeric, without prefix)
     * @param {string} [system] - System type: 'IMS' or 'CICS' (optional, defaults to CICS)
     * @returns {Promise<Customer>} Customer details
     */
    async getCustomer(customerId, system = 'CICS') {
        if (system === 'IMS') {
            // Route to IMS endpoint
            return this.request(`${this.configuration.baseUrl}/ims/customers/${customerId}`);
        } else {
            // Route to CICS endpoint
            return this.request(`${this.configuration.baseUrl}/customers/${customerId}`);
        }
    }

    /**
     * Get customer accounts
     * GET /customers/{customerId}/accounts or /ims/customers/{customerId}/accounts
     * Routes based on explicit system parameter (from C/I prefix)
     * @param {string} customerId - Unique identifier for the customer (numeric, without prefix)
     * @param {string} [system] - System type: 'IMS' or 'CICS' (optional, defaults to CICS)
     * @returns {Promise<AccountList>} List of customer accounts
     */
    async getCustomerAccounts(customerId, system = 'CICS') {
        if (system === 'IMS') {
            // Route to IMS endpoint
            return this.request(`${this.configuration.baseUrl}/ims/customers/${customerId}/accounts`);
        } else {
            // Route to CICS endpoint
            return this.request(`${this.configuration.baseUrl}/customers/${customerId}/accounts`);
        }
    }

    /**
     * Create a new customer
     * POST /customers
     * @param {Object} customerData - Customer data
     * @param {string} [customerData.title] - Title (Mr, Mrs, Miss, Ms, Dr, Drs, Professor, Sir, Lady, Lord)
     * @param {string} customerData.firstName - First name (required)
     * @param {string} customerData.lastName - Last name (required)
     * @param {string} [customerData.dateOfBirth] - Date of birth (YYYY-MM-DD)
     * @param {string} [customerData.phoneNumber] - Phone number
     * @param {Object} [customerData.address] - Address object
     * @param {string} [customerData.customerStatus] - Customer status
     * @returns {Promise<CreateCustomerResponse>} Created customer with customerId and sortCode
     */
    async createCustomer(customerData) {
        return this.request(`${this.configuration.baseUrl}/customers`, {
            method: 'POST',
            body: JSON.stringify(customerData)
        });
    }

    // Stub methods for legacy endpoints not in OpenAPI spec

    /**
     * Update customer information
     * PUT /customers/{customerId} or PUT /ims/customers/{customerId}
     * Routes based on explicit system parameter
     * @param {string} customerId - Unique identifier for the customer (numeric, without prefix)
     * @param {Object} customerData - Updated customer data
     * @param {string} [system] - System type: 'IMS' or 'CICS' (optional, defaults to CICS)
     * @returns {Promise<Customer>} Updated customer details
     */
    async updateCustomer(customerId, customerData, system = 'CICS') {
        if (system === 'IMS') {
            // Route to IMS endpoint
            return this.request(`${this.configuration.baseUrl}/ims/customers/${customerId}`, {
                method: 'PUT',
                body: JSON.stringify(customerData)
            });
        } else {
            // Route to CICS endpoint
            return this.request(`${this.configuration.baseUrl}/customers/${customerId}`, {
                method: 'PUT',
                body: JSON.stringify(customerData)
            });
        }
    }

    /**
     * Delete customer
     * DELETE /customers/{customerId}
     * @param {string} customerId - Unique customer identifier
     * @returns {Promise<void>} No content on success
     */
    async deleteCustomer(customerId) {
        await this.request(`${this.configuration.baseUrl}/customers/${customerId}`, {
            method: 'DELETE'
        });
    }

    /**
     * Search customers by name (stub - not in OpenAPI spec)
     * @param {string} name - Customer name to search for
     * @param {number} [limit=10] - Maximum number of results
     * @returns {Promise<Object>} Rejected promise
     */
    async searchCustomersByName(name, limit = 10) {
        throw new Error('Customer search by name is not supported in the OpenBanking API specification');
    }
}

/**
 * Account API operations
 * Tag: Accounts
 */
class AccountsApi extends BaseApi {
    /**
     * Get all accounts
     * GET /accounts
     * @param {Object} filters - Optional filters
     * @param {string} filters.accountType - Filter by account type (CURRENT, SAVINGS, CREDIT_CARD, LOAN)
     * @param {string} filters.status - Filter by status (ACTIVE, INACTIVE, CLOSED)
     * @returns {Promise<AccountList>} List of accounts
     */
    async getAccounts(filters = {}) {
        const params = new URLSearchParams();
        if (filters.accountType) params.append('accountType', filters.accountType);
        if (filters.status) params.append('status', filters.status);
        
        const queryString = params.toString();
        const url = queryString
            ? `${this.configuration.baseUrl}/accounts?${queryString}`
            : `${this.configuration.baseUrl}/accounts`;
        
        return this.request(url);
    }

    /**
     * Get account details
     * GET /accounts/{accountId} or /ims/accounts/{customerId}
     * @param {string} accountId - Unique identifier for the account
     * @param {string} [customerId] - Optional customer ID (if provided, routes to IMS using customerId)
     * @returns {Promise<Account>} Account details
     */
    async getAccount(accountId, customerId = null) {
        if (customerId) {
            // IMS account - use customer ID in path
            return this.request(`${this.configuration.baseUrl}/ims/accounts/${customerId}`);
        } else {
            // CICS account
            return this.request(`${this.configuration.baseUrl}/accounts/${accountId}`);
        }
    }

    /**
     * Get account balances
     * GET /accounts/{accountId}/balances or /ims/accounts/{customerId}/balances
     * @param {string} accountId - Unique identifier for the account
     * @param {string} [customerId] - Optional customer ID (if provided, routes to IMS using customerId)
     * @returns {Promise<BalanceList>} Balance information
     */
    async getAccountBalances(accountId, customerId = null) {
        if (customerId) {
            // IMS account - use customer ID in path, not account ID
            return this.request(`${this.configuration.baseUrl}/ims/accounts/${customerId}/balances`);
        } else {
            // CICS account
            return this.request(`${this.configuration.baseUrl}/accounts/${accountId}/balances`);
        }
    }

    /**
     * Get account transactions
     * GET /accounts/{accountId}/transactions
     * @param {string} accountId - Unique identifier for the account
     * @param {Object} options - Query parameters
     * @param {string} options.fromDate - Start date (ISO 8601 format)
     * @param {string} options.toDate - End date (ISO 8601 format)
     * @param {number} options.limit - Maximum number of transactions (1-100, default 50)
     * @param {number} options.offset - Number of transactions to skip (default 0)
     * @returns {Promise<TransactionList>} Transaction history
     */
    async getAccountTransactions(accountId, options = {}) {
        const params = new URLSearchParams();
        if (options.fromDate) params.append('fromDate', options.fromDate);
        if (options.toDate) params.append('toDate', options.toDate);
        if (options.limit) params.append('limit', options.limit.toString());
        if (options.offset) params.append('offset', options.offset.toString());
        
        const queryString = params.toString();
        const url = queryString
            ? `${this.configuration.baseUrl}/accounts/${accountId}/transactions?${queryString}`
            : `${this.configuration.baseUrl}/accounts/${accountId}/transactions`;
        
        return this.request(url);
    }

    /**
     * Get transaction details
     * GET /accounts/{accountId}/transactions/{transactionId}
     * @param {string} accountId - Unique identifier for the account
     * @param {string} transactionId - Unique identifier for the transaction
     * @returns {Promise<Transaction>} Transaction details
     */
    async getTransaction(accountId, transactionId) {
        return this.request(`${this.configuration.baseUrl}/accounts/${accountId}/transactions/${transactionId}`);
    }

    /**
     * Deposit funds to an account
     * POST /accounts/{accountId}/deposit (CICS)
     * POST /ims/accounts/{customerId}/{accountId}/deposit (IMS)
     * @param {string} accountId - Unique identifier for the account
     * @param {Object} depositData - Deposit data
     * @param {number} depositData.amount - Deposit amount (must be positive, minimum 0.01)
     * @param {string} depositData.sortCode - 6-digit bank sort code
     * @param {string} [depositData.description] - Description of the deposit (max 40 characters)
     * @param {string} [customerId] - Customer ID (required for IMS, optional for CICS)
     * @returns {Promise<Object>} Deposit result with updated balances
     */
    async depositToAccount(accountId, depositData, customerId = null) {
        let url;
        const system = getSystemFromCustomerId(customerId);
        
        console.log('=== DEPOSIT DEBUG ===');
        console.log('customerId received:', customerId);
        console.log('system determined:', system);
        
        // Strip the C/I prefix to get numeric ID for API
        const numericCustomerId = customerId ? customerId.toString().replace(/^[CI]/i, '') : null;
        console.log('numericCustomerId:', numericCustomerId);
        
        if (system === 'IMS' && numericCustomerId) {
            // IMS endpoint: /ims/accounts/{customerId}/{accountId}/deposit
            url = `${this.configuration.baseUrl}/ims/accounts/${numericCustomerId}/${accountId}/deposit`;
            console.log('Using IMS endpoint');
        } else {
            // CICS endpoint: /accounts/{accountId}/deposit
            url = `${this.configuration.baseUrl}/accounts/${accountId}/deposit`;
            console.log('Using CICS endpoint');
        }
        
        console.log('Final URL:', url);
        console.log('===================');
        
        return this.request(url, {
            method: 'POST',
            body: JSON.stringify(depositData)
        });
    }

    // Stub methods for legacy endpoints not in OpenAPI spec
    /**
     * Create a new account (stub - not in OpenAPI spec)
     * @param {Object} accountData - Account data
     * @returns {Promise<Object>} Rejected promise
     */
    async createAccount(accountData) {
        throw new Error('Account creation is not supported in the OpenBanking API specification');
    }

    /**
     * Update account (stub - not in OpenAPI spec)
     * @param {string} accountNumber - Unique account identifier
     * @param {Object} accountData - Updated account data
     * @returns {Promise<Object>} Rejected promise
     */
    async updateAccount(accountNumber, accountData) {
        throw new Error('Account updates are not supported in the OpenBanking API specification');
    }

    /**
     * Delete account (stub - not in OpenAPI spec)
     * @param {string} accountNumber - Unique account identifier
     * @returns {Promise<Object>} Rejected promise
     */
    async deleteAccount(accountNumber) {
        throw new Error('Account deletion is not supported in the OpenBanking API specification');
    }

    /**
     * Get accounts by customer number (stub - not in OpenAPI spec)
     * Use getCustomerAccounts from CustomersApi instead
     * @param {string} customerNumber - Customer number
     * @returns {Promise<Object>} Rejected promise
     */
    async getAccountsByCustomerNumber(customerNumber) {
        throw new Error('This endpoint is deprecated. Use api.customers.getCustomerAccounts() instead');
    }
}

/**
 * Main API client facade
 * Provides access to all API operations
 */
class ApiClient {
    constructor() {
        this.configuration = new ApiConfiguration();
        this.customers = new CustomersApi(this.configuration);
        this.accounts = new AccountsApi(this.configuration);
    }

    /**
     * Update base URL
     * @param {string} baseUrl - API base URL
     */
    setBaseUrl(baseUrl) {
        this.configuration.baseUrl = baseUrl;
    }

    /**
     * Set custom headers for all requests
     * @param {object} headers - Headers to add
     */
    setHeaders(headers) {
        this.configuration.defaultHeaders = {
            ...this.configuration.defaultHeaders,
            ...headers
        };
    }
}

// Create and export singleton instance
const apiClient = new ApiClient();

// Export for use in other modules
export default apiClient;

// Also export individual API classes for advanced usage
export { ApiClient, CustomersApi, AccountsApi, ApiConfiguration };

/**
 * TypeScript-style type definitions (for documentation)
 * Based on OpenAPI specification
 * 
 * @typedef {Object} Customer
 * @property {string} customerId - Unique identifier for the customer
 * @property {string} [title] - Customer title
 * @property {string} firstName - Customer first name
 * @property {string} lastName - Customer last name
 * @property {string} [dateOfBirth] - Customer date of birth (YYYY-MM-DD)
 * @property {string} [phoneNumber] - Customer phone number
 * @property {Address} [address] - Customer address
 * @property {string} [customerStatus] - Current status (ACTIVE, INACTIVE, SUSPENDED)
 * @property {string} [createdDate] - Date when customer account was created
 * 
 * @typedef {Object} Address
 * @property {string} [addressLine1] - Address line 1
 * @property {string} [addressLine2] - Address line 2
 * @property {string} [city] - City
 * @property {string} [postalCode] - Postal code
 * @property {string} [country] - Country
 * 
 * @typedef {Object} AccountList
 * @property {Account[]} accounts - Array of accounts
 * @property {number} [totalCount] - Total number of accounts
 * 
 * @typedef {Object} Account
 * @property {string} accountId - Unique identifier for the account
 * @property {string} accountType - Type of account (CURRENT, SAVINGS, CREDIT_CARD, LOAN)
 * @property {string} [accountSubType] - Sub-type of account
 * @property {string} currency - Currency code (ISO 4217)
 * @property {string} [nickname] - Customer-defined nickname
 * @property {string} [accountNumber] - Account number
 * @property {string} [sortCode] - Bank sort code
 * @property {string} [iban] - International Bank Account Number
 * @property {string} status - Current status (ACTIVE, INACTIVE, CLOSED)
 * @property {string} [openingDate] - Date when account was opened
 * @property {string} [customerId] - Customer ID associated with this account
 * 
 * @typedef {Object} BalanceList
 * @property {Balance[]} balances - Array of balances
 * 
 * @typedef {Object} Balance
 * @property {string} balanceType - Type of balance (AVAILABLE, CURRENT, OPENING_AVAILABLE, OPENING_BOOKED)
 * @property {number} amount - Balance amount
 * @property {string} currency - Currency code (ISO 4217)
 * @property {string} [creditDebitIndicator] - Indicates if balance is credit or debit (CREDIT, DEBIT)
 * @property {string} dateTime - Date and time of the balance
 * 
 * @typedef {Object} TransactionList
 * @property {Transaction[]} transactions - Array of transactions
 * @property {number} [totalCount] - Total number of transactions
 * @property {number} [limit] - Maximum number of transactions returned
 * @property {number} [offset] - Number of transactions skipped
 * 
 * @typedef {Object} Transaction
 * @property {string} transactionId - Unique identifier for the transaction
 * @property {string} accountId - Account identifier
 * @property {number} amount - Transaction amount
 * @property {string} currency - Currency code (ISO 4217)
 * @property {string} creditDebitIndicator - Indicates if transaction is credit or debit (CREDIT, DEBIT)
 * @property {string} status - Transaction status (PENDING, BOOKED, CANCELLED)
 * @property {string} bookingDateTime - Date and time when transaction was booked
 * @property {string} [valueDateTime] - Date and time when transaction value is applied
 * @property {string} [transactionInformation] - Additional information about the transaction
 * @property {MerchantDetails} [merchantDetails] - Merchant details
 * @property {Balance} [balance] - Balance after transaction
 * 
 * @typedef {Object} MerchantDetails
 * @property {string} [merchantName] - Name of the merchant
 * @property {string} [merchantCategoryCode] - Merchant category code
 * 
 * @typedef {Object} Error
 * @property {string} code - Error code
 * @property {string} message - Human-readable error message
 * @property {Array} [details] - Additional error details
 */

// Made with Bob