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
        // - Docker dev (port 3001): proxied by nginx to zosConnect:9080/api/*.
        // - z/OS Liberty: frontend and API share the same Liberty instance and
        //   origin, so use a relative path - works for both HTTP and HTTPS.
        baseUrl: '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
