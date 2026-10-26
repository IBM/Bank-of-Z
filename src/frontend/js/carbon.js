/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Single place that loads every Carbon Web Component used by the app.
 * Every page includes this one script instead of its own list of imports.
 */
const BASE = 'https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0';

const components = [
    'ui-shell',
    'breadcrumb',
    'button',
    'text-input',
    'select',
    'date-picker',
    'number-input',
    'modal',
    'loading',
    'notification',
    'tag'
];

await Promise.all(components.map((name) => import(`${BASE}/${name}.min.js`)));

// Made with Bob
