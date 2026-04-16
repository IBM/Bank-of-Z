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
     * GET /customers/{customerId}
     * @param {string} customerId - Unique identifier for the customer
     * @returns {Promise<Customer>} Customer details
     */
    async getCustomer(customerId) {
        return this.request(`${this.configuration.baseUrl}/customers/${customerId}`);
    }

    /**
     * Get customer accounts
     * GET /customers/{customerId}/accounts
     * @param {string} customerId - Unique identifier for the customer
     * @returns {Promise<AccountList>} List of customer accounts
     */
    async getCustomerAccounts(customerId) {
        return this.request(`${this.configuration.baseUrl}/customers/${customerId}/accounts`);
    }

    // Stub methods for legacy endpoints not in OpenAPI spec
    /**
     * Create a new customer (stub - not in OpenAPI spec)
     * @param {Object} customerData - Customer data
     * @returns {Promise<Object>} Rejected promise
     */
    async createCustomer(customerData) {
        throw new Error('Customer creation is not supported in the OpenBanking API specification');
    }

    /**
     * Update customer (stub - not in OpenAPI spec)
     * @param {string} customerNumber - Unique customer identifier
     * @param {Object} customerData - Updated customer data
     * @returns {Promise<Object>} Rejected promise
     */
    async updateCustomer(customerNumber, customerData) {
        throw new Error('Customer updates are not supported in the OpenBanking API specification');
    }

    /**
     * Delete customer (stub - not in OpenAPI spec)
     * @param {string} customerNumber - Unique customer identifier
     * @returns {Promise<Object>} Rejected promise
     */
    async deleteCustomer(customerNumber) {
        throw new Error('Customer deletion is not supported in the OpenBanking API specification');
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
     * GET /accounts/{accountId}
     * @param {string} accountId - Unique identifier for the account
     * @returns {Promise<Account>} Account details
     */
    async getAccount(accountId) {
        return this.request(`${this.configuration.baseUrl}/accounts/${accountId}`);
    }

    /**
     * Get account balances
     * GET /accounts/{accountId}/balances
     * @param {string} accountId - Unique identifier for the account
     * @returns {Promise<BalanceList>} Balance information
     */
    async getAccountBalances(accountId) {
        return this.request(`${this.configuration.baseUrl}/accounts/${accountId}/balances`);
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
 * @property {string} email - Customer email address
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