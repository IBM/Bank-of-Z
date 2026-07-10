/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Application Configuration
 */
export const config = {
    api: {
        // Base URL for API endpoints.
        // Always relative — works for both Docker (Node proxy) and Liberty
        // (z/OS Connect hosts both frontend WAR and api.war on same origin).
        baseUrl: '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
