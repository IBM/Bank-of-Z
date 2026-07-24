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
        // - Docker dev (port 3001): use relative '/api' so requests are proxied
        //   by nginx to the zosConnect container at zosConnect:9080/api/*.
        //   The /api prefix is preserved end-to-end; nginx does not strip it.
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
