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
    const [year, month, day] = dateString.split('-');
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
 * Format currency
 */
export function formatCurrency(amount) {
    return new Intl.NumberFormat('en-GB', {
        style: 'currency',
        currency: 'GBP'
    }).format(amount);
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
            <cds-modal-heading>${message}</cds-modal-heading>
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
            <cds-modal-heading>${title}</cds-modal-heading>
        </cds-modal-header>
        <cds-modal-body>
            <p>${message}</p>
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
            <cds-modal-heading>${title}</cds-modal-heading>
        </cds-modal-header>
        <cds-modal-body>
            <p>${message}</p>
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
