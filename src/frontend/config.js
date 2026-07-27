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
        //   Liberty instances. Use the same protocol and hostname as the current
        //   page, but point at the z/OS Connect HTTPS port (9444).
        baseUrl: window.location.port === '3001'
            ? '/api'
            : window.location.protocol + '//' + window.location.hostname + ':9444/api'
    },
    defaults: {
        sortCode: '987654'
    }
};

// Made with Bob
