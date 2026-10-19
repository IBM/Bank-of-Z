/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

import api from '../api.js';
import { validateCustomerId, parseCustomerId, formatCustomerId, escapeHtml, parseDate } from '../utils.js';

/**
 * Shared customer / account lookup helpers.
 *
 * Every page that needs a customer uses these, so the rule is the same
 * everywhere: one box, the ID must start with C (CICS) or I (IMS).
 */

export const CUSTOMER_ID_PLACEHOLDER = 'e.g. C0000000042';
export const CUSTOMER_ID_HELP = 'Start with C for a CICS customer or I for an IMS customer.';

/**
 * Parse and validate a typed customer ID.
 * @param {string} raw
 * @returns {{ok: true, id: string, system: 'CICS'|'IMS', ref: string} | {ok: false, error: string}}
 *   id is the numeric part, ref is the prefixed form used in URLs and on screen.
 */
export function parseCustomerRef(raw) {
    const validation = validateCustomerId(raw);
    if (!validation.valid) return { ok: false, error: validation.error };
    const parsed = parseCustomerId(raw);
    if (!parsed) return { ok: false, error: 'Customer ID is not valid' };
    return {
        ok: true,
        id: parsed.customerId,
        system: parsed.system,
        ref: formatCustomerId(parsed.customerId, parsed.system)
    };
}

/**
 * Build a link to another page. Empty parameters are left out.
 */
export function pageUrl(page, params = {}) {
    const query = Object.entries(params)
        .filter(([, value]) => value !== undefined && value !== null && value !== '')
        .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
        .join('&');
    return query ? `${page}?${query}` : page;
}

export const urls = {
    customer: (ref) => pageUrl('customer-details.html', { customerId: ref }),
    account: (accountId, ref) => pageUrl('account-details.html', { accountId, customerId: ref }),
    transactions: (accountId, ref) => pageUrl('account-transactions.html', { accountId, customerId: ref }),
    transaction: (accountId, transactionId, ref) =>
        pageUrl('transaction-details.html', { accountId, transactionId, customerId: ref }),
    deposit: (accountId, ref) => pageUrl('account-deposit.html', { accountId, customerId: ref }),
    transfer: (accountId, ref) => pageUrl('account-transfer.html', { accountId, customerId: ref }),
    createAccount: (ref) => pageUrl('account-create.html', { customerId: ref })
};

/**
 * Show or clear an error on a cds-text-input.
 */
export function setFieldError(input, message) {
    if (message) {
        input.setAttribute('invalid', '');
        input.setAttribute('invalid-text', message);
    } else {
        input.removeAttribute('invalid');
        input.removeAttribute('invalid-text');
    }
}

/**
 * HTML for the standard customer lookup row (input + button).
 */
export function customerLookupHtml({
    inputId = 'customerId',
    buttonId = 'customer-lookup-btn',
    label = 'Customer ID',
    buttonLabel = 'Find customer',
    value = ''
} = {}) {
    return `
        <div class="lookup">
            <cds-text-input id="${inputId}" label="${escapeHtml(label)}"
                placeholder="${CUSTOMER_ID_PLACEHOLDER}"
                helper-text="${CUSTOMER_ID_HELP}"
                value="${escapeHtml(value)}"></cds-text-input>
            <cds-button id="${buttonId}">${escapeHtml(buttonLabel)}</cds-button>
        </div>
    `;
}

/**
 * Wire a customer lookup row. Validates the C/I prefix, then calls onFound(ref).
 */
export function bindCustomerLookup({ inputId = 'customerId', buttonId = 'customer-lookup-btn', onFound }) {
    const input = document.getElementById(inputId);
    const button = document.getElementById(buttonId);

    const submit = () => {
        const ref = parseCustomerRef(input.value || '');
        setFieldError(input, ref.ok ? '' : ref.error);
        if (ref.ok) onFound(ref);
    };

    button.addEventListener('click', submit);
    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            submit();
        }
    });
}

/**
 * Read ?customerId=...&accountId=... from the page URL.
 * @returns {{accountId: string|null, customer: ReturnType<typeof parseCustomerRef>|null}}
 */
export function readContext() {
    const params = new URLSearchParams(window.location.search);
    const rawCustomer = params.get('customerId');
    return {
        accountId: params.get('accountId') || params.get('id'),
        customer: rawCustomer ? parseCustomerRef(rawCustomer) : null,
        params
    };
}

/**
 * Fetch the accounts belonging to a customer (CICS or IMS).
 */
export async function fetchCustomerAccounts(ref) {
    const response = await api.customers.getCustomerAccounts(ref.id, ref.system);
    return response.accounts || [];
}

/**
 * Load a single account plus the customer it belongs to.
 *
 * CICS: GET /accounts/{id}; the customer is read from the account when not supplied.
 * IMS:  there is no single-account route, so the account is taken from the
 *       customer's account list (which also carries the balances).
 *
 * @param {string} accountId
 * @param {ReturnType<typeof parseCustomerRef>|null} customer - from the URL, if any
 * @returns {Promise<{account: object, system: string, ref: string|null, customerNumber: string|null}>}
 */
export async function loadAccountContext(accountId, customer) {
    if (customer && customer.ok && customer.system === 'IMS') {
        const accounts = await fetchCustomerAccounts(customer);
        const account = accounts.find((a) => String(a.accountId) === String(accountId));
        if (!account) {
            const error = new Error(`Account ${accountId} was not found for customer ${customer.ref}`);
            error.status = 404;
            throw error;
        }
        return { account, system: 'IMS', ref: customer.ref, customerNumber: customer.id };
    }

    const account = await api.accounts.getAccount(accountId);
    const ref = customer && customer.ok
        ? customer.ref
        : (account.customerId ? formatCustomerId(account.customerId, 'CICS') : null);
    return { account, system: 'CICS', ref, customerNumber: account.customerId || null };
}

/**
 * HTML for a single-date picker. Shows dd/mm/yyyy; read it with readDatePicker().
 */
export function datePickerHtml({ id, label, value = '' }) {
    return `
        <cds-date-picker date-format="d/m/Y">
            <cds-date-picker-input id="${id}" kind="single" label-text="${escapeHtml(label)}"
                placeholder="dd/mm/yyyy" value="${escapeHtml(value)}"></cds-date-picker-input>
        </cds-date-picker>
    `;
}

/**
 * Read a date picker as an ISO date (YYYY-MM-DD), or '' if empty.
 */
export function readDatePicker(id) {
    return parseDate((document.getElementById(id).value || '').trim());
}

/**
 * Full display name for a customer.
 */
export function customerName(customer) {
    return [customer.title, customer.firstName, customer.lastName].filter(Boolean).join(' ').trim();
}

/**
 * System tag (CICS / IMS) as HTML.
 */
export function systemTagHtml(system) {
    return `<cds-tag type="${system === 'IMS' ? 'purple' : 'blue'}" size="sm">${system}</cds-tag>`;
}

/**
 * Message used on pages where an IMS customer has fewer actions available.
 */
export const IMS_LIMITED_NOTE =
    'This is an IMS customer. Viewing, editing details and credit / debit are available; ' +
    'other actions are not implemented for IMS yet.';

// Made with Bob
