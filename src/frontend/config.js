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
        // - z/OS Liberty: frontend (FEBOZ) and API (BAQBOZ) are on separate
        //   Liberty instances. Match the protocol used to load the frontend page:
        //     https://host:9445 → https://host:9444/api
        //     http://host:9081  → http://host:9080/api
        baseUrl: window.location.port === '3001'
            ? '/api'
            : window.location.protocol + '//' + window.location.hostname + ':' +
              (window.location.protocol === 'https:' ? '9444' : '9080') + '/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
