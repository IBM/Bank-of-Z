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
        // - Docker (port 3001): use relative '/api' so requests go through the
        //   Node server.js proxy, which forwards to z/OS Connect internally.
        //   Direct cross-origin calls from 3001 → 9080 are blocked by CORS.
        // - z/OS Liberty (port 9081): use absolute URL directly to z/OS Connect
        //   on port 9080 (same hostname, CORS not an issue on z/OS).
        baseUrl: window.location.port === '3001'
            ? '/api'
            : 'http://' + window.location.hostname + ':9080/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
