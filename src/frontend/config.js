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
        // In production, this should point to the z/OS Connect server on port 22503
        // The frontend is served from a separate Liberty server on port 20705
        baseUrl: window.location.hostname === 'localhost'
            ? 'http://localhost:22503/api'  // Local z/OS Connect server
            : 'http://' + window.location.hostname + ':22503/api'  // Production z/OS Connect server
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
