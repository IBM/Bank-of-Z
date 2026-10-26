/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Application header.
 * One navigation structure for every page: task-based links, no dead icons.
 */
export function createHeader() {
    return `
        <cds-header aria-label="Bank of Z Sample Application" class="cds--g100">
            <cds-header-name href="admin.html" prefix="IBM">Bank of Z</cds-header-name>
            <cds-header-nav menu-bar-label="Bank of Z navigation">
                <cds-header-nav-item href="admin.html">Home</cds-header-nav-item>
                <cds-header-nav-item href="admin.html#find-customer">Find customer</cds-header-nav-item>
                <cds-header-nav-item href="admin.html#find-account">Find account</cds-header-nav-item>
                <cds-header-nav-item href="customer-create.html">Create customer</cds-header-nav-item>
            </cds-header-nav>
        </cds-header>
    `;
}

// Made with Bob
