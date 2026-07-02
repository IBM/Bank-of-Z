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
        // Uses a relative path so all requests go through the frontend server's
        // proxy (server.js), which forwards them to z/OS Connect on port 9080.
        // This avoids cross-origin (CORS) errors when the frontend and backend
        // are on different ports.
        baseUrl: '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
