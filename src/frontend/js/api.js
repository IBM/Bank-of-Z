/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * CICS Banking Sample Application API Client
 * Generated from OpenAPI specification
 * 
 * This is a zero-dependency API client using native fetch()
 * Based on: src/bank-test-backend/openapi-spec.yaml
 */

import { config } from '../config.js';

/**
 * Base API configuration
 */
class ApiConfiguration {
    constructor() {
        this.customerBaseUrl = config.api.customerUrl;
        this.accountBaseUrl = config.api.accountUrl;
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
                error.timestamp = data.timestamp;
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
     * Create a new customer
     * POST /customer
     * @param {CustomerCreateRequest} customerCreateRequest - Customer data
     * @returns {Promise<Customer>} Created customer
     */
    async createCustomer(customerCreateRequest) {
        return this.request(`${this.configuration.customerBaseUrl}`, {
            method: 'POST',
            body: JSON.stringify(customerCreateRequest)
        });
    }

    /**
     * Get customer by number
     * GET /customer/{customerNumber}
     * @param {string} customerNumber - Unique customer identifier
     * @returns {Promise<Customer>} Customer details
     */
    async getCustomerByNumber(customerNumber) {
        return this.request(`${this.configuration.customerBaseUrl}/${customerNumber}`);
    }

    /**
     * Update customer
     * PUT /customer/{customerNumber}
     * @param {string} customerNumber - Unique customer identifier
     * @param {CustomerUpdateRequest} customerUpdateRequest - Updated customer data
     * @returns {Promise<Customer>} Updated customer
     */
    async updateCustomer(customerNumber, customerUpdateRequest) {
        return this.request(`${this.configuration.customerBaseUrl}/${customerNumber}`, {
            method: 'PUT',
            body: JSON.stringify(customerUpdateRequest)
        });
    }

    /**
     * Delete customer
     * DELETE /customer/{customerNumber}
     * Note: Customer must have no associated accounts before deletion
     * @param {string} customerNumber - Unique customer identifier
     * @returns {Promise<{message: string}>} Deletion confirmation
     */
    async deleteCustomer(customerNumber) {
        return this.request(`${this.configuration.customerBaseUrl}/${customerNumber}`, {
            method: 'DELETE'
        });
    }

    /**
     * Search customers by name
     * GET /customer/name
     * @param {string} name - Customer name to search for (case sensitive)
     * @param {number} [limit=10] - Maximum number of results (max 10)
     * @returns {Promise<CustomerSearchResponse>} Search results
     */
    async searchCustomersByName(name, limit = 10) {
        const params = new URLSearchParams({ name, limit: limit.toString() });
        return this.request(`${this.configuration.customerBaseUrl}/name?${params}`);
    }
}

/**
 * Account API operations
 * Tag: Accounts
 */
class AccountsApi extends BaseApi {
    /**
     * Create a new account
     * POST /account
     * @param {AccountCreateRequest} accountCreateRequest - Account data
     * @returns {Promise<Account>} Created account
     */
    async createAccount(accountCreateRequest) {
        return this.request(`${this.configuration.accountBaseUrl}`, {
            method: 'POST',
            body: JSON.stringify(accountCreateRequest)
        });
    }

    /**
     * Get account by number
     * GET /account/{accountNumber}
     * @param {string} accountNumber - Unique account identifier
     * @returns {Promise<Account>} Account details
     */
    async getAccountByNumber(accountNumber) {
        return this.request(`${this.configuration.accountBaseUrl}/${accountNumber}`);
    }

    /**
     * Update account
     * PUT /account/{accountNumber}
     * @param {string} accountNumber - Unique account identifier
     * @param {AccountUpdateRequest} accountUpdateRequest - Updated account data
     * @returns {Promise<Account>} Updated account
     */
    async updateAccount(accountNumber, accountUpdateRequest) {
        return this.request(`${this.configuration.accountBaseUrl}/${accountNumber}`, {
            method: 'PUT',
            body: JSON.stringify(accountUpdateRequest)
        });
    }

    /**
     * Delete account
     * DELETE /account/{accountNumber}
     * @param {string} accountNumber - Unique account identifier
     * @returns {Promise<{message: string}>} Deletion confirmation
     */
    async deleteAccount(accountNumber) {
        return this.request(`${this.configuration.accountBaseUrl}/${accountNumber}`, {
            method: 'DELETE'
        });
    }

    /**
     * Get accounts by customer number
     * GET /account/retrieveByCustomerNumber/{customerNumber}
     * @param {string} customerNumber - Customer number to retrieve accounts for
     * @returns {Promise<AccountListResponse>} List of accounts
     */
    async getAccountsByCustomerNumber(customerNumber) {
        return this.request(`${this.configuration.accountBaseUrl}/retrieveByCustomerNumber/${customerNumber}`);
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
     * Update base URLs for customer and account services
     * @param {string} customerUrl - Customer service base URL
     * @param {string} accountUrl - Account service base URL
     */
    setBaseUrls(customerUrl, accountUrl) {
        this.configuration.customerBaseUrl = customerUrl;
        this.configuration.accountBaseUrl = accountUrl;
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
 * 
 * @typedef {Object} Customer
 * @property {string} id - Unique customer identifier
 * @property {string} customerName - Full name with title
 * @property {string} customerAddress - Customer's address
 * @property {string} dateOfBirth - Date of birth (YYYY-MM-DD)
 * @property {string} sortCode - Bank sort code
 * @property {number} [customerCreditScore] - Credit score
 * @property {string} [customerCreditScoreReviewDate] - Next review date
 * 
 * @typedef {Object} CustomerCreateRequest
 * @property {string} customerName - Full name with title
 * @property {string} customerAddress - Customer's address
 * @property {string} dateOfBirth - Date of birth (YYYY-MM-DD)
 * @property {string} sortCode - Bank sort code
 * 
 * @typedef {Object} CustomerUpdateRequest
 * @property {string} customerName - Full name with title
 * @property {string} customerAddress - Customer's address
 * @property {string} dateOfBirth - Date of birth (YYYY-MM-DD)
 * @property {string} sortCode - Bank sort code
 * @property {number} creditScore - Credit score
 * 
 * @typedef {Object} CustomerSearchResponse
 * @property {Customer[]} customers - Array of matching customers
 * 
 * @typedef {Object} Account
 * @property {string} id - Unique account identifier
 * @property {string} customerNumber - Customer number
 * @property {string} accountType - MORTGAGE|ISA|LOAN|SAVING|CURRENT
 * @property {string} interestRate - Interest rate
 * @property {string} overdraft - Overdraft limit
 * @property {number} availableBalance - Available balance
 * @property {number} actualBalance - Actual balance
 * @property {string} dateOpened - Date opened (YYYY-MM-DD)
 * @property {string} lastStatementDate - Last statement date
 * @property {string} nextStatementDate - Next statement date
 * @property {string} sortCode - Bank sort code
 * 
 * @typedef {Object} AccountCreateRequest
 * @property {string} customerNumber - Customer number
 * @property {string} accountType - MORTGAGE|ISA|LOAN|SAVING|CURRENT
 * @property {string} interestRate - Interest rate
 * @property {string} overdraft - Overdraft limit
 * @property {string} dateOpened - Date opened (YYYY-MM-DD)
 * @property {string} sortCode - Bank sort code
 * 
 * @typedef {Object} AccountUpdateRequest
 * @property {string} id - Account identifier
 * @property {string} customerNumber - Customer number
 * @property {string} accountType - MORTGAGE|ISA|LOAN|SAVING|CURRENT
 * @property {string} interestRate - Interest rate
 * @property {string} overdraft - Overdraft limit
 * @property {number} availableBalance - Available balance
 * @property {number} actualBalance - Actual balance
 * @property {string} dateOpened - Date opened (YYYY-MM-DD)
 * @property {string} lastStatementDate - Last statement date
 * @property {string} nextStatementDate - Next statement date
 * @property {string} sortCode - Bank sort code
 * 
 * @typedef {Object} AccountListResponse
 * @property {Account[]} accounts - Array of accounts
 * @property {number} numberOfAccounts - Total number of accounts
 * 
 * @typedef {Object} Error
 * @property {string} message - Error message
 * @property {string} code - Error code
 * @property {string} timestamp - Error timestamp
 */

// Made with Bob