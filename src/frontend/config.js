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
        // - Docker (port 3001): use relative '/api' — proxied by Node server.js
        // - Liberty HTTPS (port 9444): call z/OS Connect directly on HTTPS 9445.
        //   Same host, same RACF CA cert — browser already trusts it.
        //   End-to-end HTTPS: browser → Liberty(9444) and browser → zOSConnect(9445).
        // - Liberty HTTP (port 9081): call z/OS Connect directly on HTTP 9080.
        baseUrl: window.location.port === '3001'
            ? '/api'
            : window.location.protocol + '//' + window.location.hostname +
              (window.location.protocol === 'https:' ? ':9445' : ':9080') + '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
