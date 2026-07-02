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
        // Base URL for API endpoints
        // In production, this should point to the z/OS Connect server
        // The frontend is served from a separate Liberty server on port 9081/9444
        // Automatically uses the same protocol (HTTP/HTTPS) as the frontend
        baseUrl: window.location.hostname === 'localhost'
            ? 'http://localhost:9080/api'  // Local z/OS Connect server
            : window.location.protocol + '//' + window.location.hostname + ':' +
              (window.location.protocol === 'https:' ? '9443' : '9080') + '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
