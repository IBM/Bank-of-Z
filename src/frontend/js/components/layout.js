/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

import { createHeader } from './headers.js';
import { escapeHtml } from '../utils.js';

/**
 * Shared page shell. Every page has the same skeleton:
 *
 *   <div id="header-container"></div>
 *   <main class="page">
 *     <section class="page-banner"><div class="page-inner" id="banner"></div></section>
 *     <section class="page-content"><div class="page-inner">
 *       <div id="notification-container"></div>
 *       ...
 *
 * so the breadcrumb, title and content always share the same left edge.
 */

/**
 * Render the header and banner.
 * @param {Object} options
 * @param {Array<{label: string, href?: string}>} options.crumbs - Breadcrumb trail, last item is the current page
 * @param {string} options.title - Page title
 * @param {string} [options.subtitle] - Optional line under the title
 * @param {string} [options.actionsHtml] - Optional buttons shown under the title
 */
export function mountPage({ crumbs, title, subtitle = '', actionsHtml = '' }) {
    document.getElementById('header-container').innerHTML = createHeader();
    setBanner({ crumbs, title, subtitle, actionsHtml });
}

/**
 * Re-render the banner, e.g. once the customer's name is known.
 */
export function setBanner({ crumbs, title, subtitle = '', actionsHtml = '' }) {
    const items = crumbs.map((crumb, index) => {
        const isLast = index === crumbs.length - 1;
        const href = crumb.href && !isLast ? ` href="${escapeHtml(crumb.href)}"` : '';
        return `<cds-breadcrumb-item><cds-breadcrumb-link${href}>${escapeHtml(crumb.label)}</cds-breadcrumb-link></cds-breadcrumb-item>`;
    }).join('');

    document.getElementById('banner').innerHTML = `
        <cds-breadcrumb>${items}</cds-breadcrumb>
        <h1 class="page-title">${escapeHtml(title)}</h1>
        ${subtitle ? `<p class="page-subtitle">${escapeHtml(subtitle)}</p>` : ''}
        ${actionsHtml ? `<div class="page-actions">${actionsHtml}</div>` : ''}
    `;
    document.title = `${title} - Bank of Z`;
}

/**
 * Show an inline notification at the top of the page content.
 * @param {'error'|'success'|'info'|'warning'} kind
 */
export function notify(kind, title, message) {
    const container = document.getElementById('notification-container');
    container.innerHTML = `
        <cds-inline-notification kind="${kind}" title="${escapeHtml(title)}" subtitle="${escapeHtml(message)}" hide-close-button></cds-inline-notification>
    `;
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

export function clearNotification() {
    document.getElementById('notification-container').innerHTML = '';
}

/**
 * Turn an API error into a short user-facing message.
 */
export function errorMessage(error, fallback = 'Something went wrong') {
    if (!error) return fallback;
    if (error.code === 'IMS_NOT_IMPLEMENTED') return error.message;
    if (error.message && error.message.includes('Failed to fetch')) {
        return 'Failed to connect to the server. Please check your connection.';
    }
    const details = Array.isArray(error.details)
        ? ' ' + error.details.map((d) => `${d.field}: ${d.issue}`).join('; ')
        : '';
    return (error.message || fallback) + details;
}

// Made with Bob
