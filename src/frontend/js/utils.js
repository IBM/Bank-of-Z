/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Utility Functions
 */

/**
 * Format date from YYYY-MM-DD to DD/MM/YYYY
 */
export function formatDate(dateString) {
    if (!dateString) return '';
    const [year, month, day] = String(dateString).substring(0, 10).split('-');
    return `${day}/${month}/${year}`;
}

/**
 * Format date from DD/MM/YYYY to YYYY-MM-DD
 */
export function parseDate(dateString) {
    if (!dateString) return '';
    const parts = dateString.split('/');
    if (parts.length === 3) {
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
    }
    return dateString;
}


/**
* Escape HTML special chaarcters so user supplied text can't break out
* of the innerHTML templates used by modal helpers
*/
export function escapeHtml(value) {
    const div = document.createElement('div');
    div.textContent = value;
    return div.innerHTML;
}

/**
 * Format currency
 */
export function formatCurrency(amount, currency) {
    const value = Number(amount);
    if (amount === null || amount === undefined || amount === '' || Number.isNaN(value)) return 'N/A';
    const code = currency || 'GBP';
    const locale = code === 'USD' ? 'en-US' : 'en-GB';
    return new Intl.NumberFormat(locale, {
        style: 'currency',
        currency: code
    }).format(value);
}

/**
 * Parse customer ID with system prefix (C for CICS, I for IMS)
 * Returns { system: 'CICS'|'IMS', customerId: 'digits' }
 */
export function parseCustomerId(input) {
    if (!input) return null;
    
    const trimmed = input.trim().toUpperCase();
    
    // Check for C prefix (CICS)
    if (trimmed.startsWith('C')) {
        const digits = trimmed.substring(1);
        if (/^\d+$/.test(digits)) {
            return { system: 'CICS', customerId: digits };
        }
    }
    
    // Check for I prefix (IMS)
    if (trimmed.startsWith('I')) {
        const digits = trimmed.substring(1);
        if (/^\d{9}$/.test(digits)) { // IMS requires exactly 9 digits
            return { system: 'IMS', customerId: digits };
        }
    }
    
    return null;
}

/**
 * Format customer ID with system prefix
 * @param {string} customerId - The numeric customer ID
 * @param {string} system - 'CICS' or 'IMS'
 * @returns {string} Formatted customer ID with prefix (e.g., 'C1234' or 'I000000015')
 */
export function formatCustomerId(customerId, system) {
    if (!customerId) return '';
    const prefix = system === 'IMS' ? 'I' : 'C';
    return `${prefix}${customerId}`;
}

/**
 * Validate customer ID format
 * @param {string} input - Customer ID with prefix
 * @returns {Object} { valid: boolean, error: string|null, system: string|null }
 */
export function validateCustomerId(input) {
    if (!input || !input.trim()) {
        return { valid: false, error: 'Customer ID is required', system: null };
    }
    
    const trimmed = input.trim().toUpperCase();
    
    // Must start with C or I
    if (!trimmed.startsWith('C') && !trimmed.startsWith('I')) {
        return { 
            valid: false, 
            error: 'Customer ID must start with C (CICS) or I (IMS)', 
            system: null 
        };
    }
    
    const prefix = trimmed[0];
    const digits = trimmed.substring(1);
    
    // Check if rest is numeric
    if (!/^\d+$/.test(digits)) {
        return { 
            valid: false, 
            error: 'Customer ID must contain only digits after the prefix', 
            system: null 
        };
    }
    
    // IMS requires exactly 9 digits
    if (prefix === 'I' && digits.length !== 9) {
        return { 
            valid: false, 
            error: 'IMS customer ID must have exactly 9 digits after I prefix (e.g., I000000015)', 
            system: null 
        };
    }
    
    return {
        valid: true,
        error: null,
        system: prefix === 'I' ? 'IMS' : 'CICS'
    };
}

/**
 * Show loading modal
 */
export function showLoadingModal(message = 'Loading...') {
    const modal = document.createElement('cds-modal');
    modal.id = 'loading-modal';
    modal.setAttribute('open', '');
    modal.setAttribute('prevent-close', '');
    modal.innerHTML = `
        <cds-modal-header>
            <cds-modal-heading>${escapeHtml(message)}</cds-modal-heading>
        </cds-modal-header>
    `;
    document.body.appendChild(modal);
    return modal;
}

/**
 * Hide loading modal
 */
export function hideLoadingModal() {
    const modal = document.getElementById('loading-modal');
    if (modal) {
        modal.remove();
    }
}

/**
 * Show success modal
 */
export function showSuccessModal(title, message, onClose) {
    const modal = document.createElement('cds-modal');
    modal.id = 'success-modal';
    modal.setAttribute('open', '');
    modal.innerHTML = `
        <cds-modal-header>
            <cds-modal-heading>${escapeHtml(title)}</cds-modal-heading>
        </cds-modal-header>
        <cds-modal-body>
            <p>${escapeHtml(message)}</p>
        </cds-modal-body>
        <cds-modal-footer>
            <cds-modal-footer-button kind="primary" data-modal-close>OK</cds-modal-footer-button>
        </cds-modal-footer>
    `;
    
    modal.addEventListener('cds-modal-closed', () => {
        modal.remove();
        if (onClose) onClose();
    });
    
    document.body.appendChild(modal);
    return modal;
}

/**
 * Show error modal
 */
export function showErrorModal(title, message) {
    const modal = document.createElement('cds-modal');
    modal.id = 'error-modal';
    modal.setAttribute('open', '');
    modal.setAttribute('danger', '');
    modal.innerHTML = `
        <cds-modal-header>
            <cds-modal-heading>${escapeHtml(title)}</cds-modal-heading>
        </cds-modal-header>
        <cds-modal-body>
            <p>${escapeHtml(message)}</p>
        </cds-modal-body>
        <cds-modal-footer>
            <cds-modal-footer-button kind="primary" data-modal-close>OK</cds-modal-footer-button>
        </cds-modal-footer>
    `;
    
    modal.addEventListener('cds-modal-closed', () => {
        modal.remove();
    });
    
    document.body.appendChild(modal);
    return modal;
}

/**
 * Show a confirmation modal. Resolves true if the user confirms, false otherwise.
 * @param {string} title - Modal heading
 * @param {string} message - Body text
 * @param {Object} [options]
 * @param {string} [options.confirmLabel] - Label of the confirm button
 * @param {boolean} [options.danger] - Style as a destructive action
 * @returns {Promise<boolean>}
 */
export function showConfirmModal(title, message, { confirmLabel = 'Confirm', danger = false } = {}) {
    return new Promise((resolve) => {
        const modal = document.createElement('cds-modal');
        modal.id = 'confirm-modal';
        modal.setAttribute('open', '');
        if (danger) modal.setAttribute('danger', '');
        modal.innerHTML = `
            <cds-modal-header>
                <cds-modal-heading>${escapeHtml(title)}</cds-modal-heading>
            </cds-modal-header>
            <cds-modal-body>
                <p>${escapeHtml(message)}</p>
            </cds-modal-body>
            <cds-modal-footer>
                <cds-modal-footer-button kind="secondary" data-modal-close>Cancel</cds-modal-footer-button>
                <cds-modal-footer-button kind="${danger ? 'danger' : 'primary'}" id="confirm-modal-ok">${escapeHtml(confirmLabel)}</cds-modal-footer-button>
            </cds-modal-footer>
        `;

        let confirmed = false;
        modal.querySelector('#confirm-modal-ok').addEventListener('click', () => {
            confirmed = true;
            modal.removeAttribute('open');
            modal.remove();
            resolve(true);
        });
        modal.addEventListener('cds-modal-closed', () => {
            modal.remove();
            if (!confirmed) resolve(false);
        });

        document.body.appendChild(modal);
    });
}

/**
 * Validate form fields
 */
export function validateForm(formData, requiredFields) {
    const errors = [];
    
    for (const field of requiredFields) {
        if (!formData[field] || formData[field].trim() === '') {
            errors.push(`${field} is required`);
        }
    }
    
    return errors;
}

/**
 * Debounce function
 */
export function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Made with Bob
