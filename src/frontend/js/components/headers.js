/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Reusable Header Components
 */

/**
 * Create unified header with optional side navigation
 * @param {boolean} includeSideNav - Whether to include the side navigation
 */
export function createHeader(includeSideNav = false) {
    const indexLink = `<cds-header-name href="index.html" prefix="IBM">
            CICS Banking Sample Application
        </cds-header-name>`

    const sideNavContent = includeSideNav ? `
        <cds-header-menu-button button-label-active="Close menu" button-label-inactive="Open menu" style="display: block;"></cds-header-menu-button>
        ${indexLink}
        <cds-side-nav aria-label="Side navigation" collapse-mode="fixed">
            <cds-side-nav-items>
                <cds-side-nav-menu title="Create">
                    <cds-side-nav-menu-item href="customer-create.html">
                        Create Customer
                    </cds-side-nav-menu-item>
                    <cds-side-nav-menu-item href="account-create.html">
                        Create Account
                    </cds-side-nav-menu-item>
                </cds-side-nav-menu>
                
                <cds-side-nav-menu title="Delete">
                    <cds-side-nav-menu-item href="customer-delete.html">
                        Delete Customer
                    </cds-side-nav-menu-item>
                    <cds-side-nav-menu-item href="account-delete.html">
                        Delete Account
                    </cds-side-nav-menu-item>
                </cds-side-nav-menu>
                
                <cds-side-nav-menu title="View Details">
                    <cds-side-nav-menu-item href="customer-details.html">
                        View Customer Details
                    </cds-side-nav-menu-item>
                    <cds-side-nav-menu-item href="account-details.html">
                        View Account Details
                    </cds-side-nav-menu-item>
                </cds-side-nav-menu>
                
                <cds-side-nav-menu title="Update Details">
                    <cds-side-nav-menu-item href="customer-details.html">
                        Update Customer Details
                    </cds-side-nav-menu-item>
                    <cds-side-nav-menu-item href="account-details.html">
                        Update Account Details
                    </cds-side-nav-menu-item>
                </cds-side-nav-menu>
            </cds-side-nav-items>
        </cds-side-nav>
    ` : `
        ${indexLink}
    `;

    const loginOrLogout = includeSideNav ? `
        <cds-header-global-action aria-label="User Profile" tooltip-text="User Profile">
            <svg slot="icon" width="20" height="20" viewBox="0 0 32 32">
                <path d="M16,4a5,5,0,1,1-5,5,5,5,0,0,1,5-5m0-2a7,7,0,1,0,7,7A7,7,0,0,0,16,2Z"/>
                <path d="M26,30H24V25a5,5,0,0,0-5-5H13a5,5,0,0,0-5,5v5H6V25a7,7,0,0,1,7-7h6a7,7,0,0,1,7,7Z"/>
            </svg>
        </cds-header-global-action>
        
        <cds-header-global-action aria-label="Logout" tooltip-text="Logout">
            <a href="index.html" style="display: flex; align-items: center; color: inherit; text-decoration: none;">
                <svg slot="icon" width="20" height="20" viewBox="0 0 32 32">
                    <path d="M6,30H4a2,2,0,0,1-2-2V4A2,2,0,0,1,4,2H6V4H4V28H6Z"/>
                    <path d="M21.4141,20.5859,26.5859,15.4141,21.4141,10.2422,22.8284,8.8279,29.4142,15.4137,22.8284,22,21.4141,20.5859Z"/>
                    <rect x="10" y="14" width="18" height="2"/>
                </svg>
            </a>
        </cds-header-global-action>
    ` : `
        <cds-header-global-action aria-label="User" tooltip-text="Login">
            <a href="admin.html" style="display: flex; align-items: center; color: inherit; text-decoration: none;">
                <svg slot="icon" width="20" height="20" viewBox="0 0 32 32">
                    <path d="M16,4a5,5,0,1,1-5,5,5,5,0,0,1,5-5m0-2a7,7,0,1,0,7,7A7,7,0,0,0,16,2Z"/>
                    <path d="M26,30H24V25a5,5,0,0,0-5-5H13a5,5,0,0,0-5,5v5H6V25a7,7,0,0,1,7-7h6a7,7,0,0,1,7,7Z"/>
                </svg>
            </a>
        </cds-header-global-action>
    `;

    return `
        <cds-header aria-label="CICS Banking Sample Application" class="cds--g100">
            ${sideNavContent}
            
            <cds-header-global-bar>
                <cds-header-global-action aria-label="Search" tooltip-text="Search">
                    <svg slot="icon" width="20" height="20" viewBox="0 0 32 32">
                        <path d="M29,27.5859l-7.5521-7.5521a11.0177,11.0177,0,1,0-1.4141,1.4141L27.5859,29ZM4,13a9,9,0,1,1,9,9A9.01,9.01,0,0,1,4,13Z"/>
                    </svg>
                </cds-header-global-action>
                
                <cds-header-global-action aria-label="Notifications" tooltip-text="Notifications">
                    <svg slot="icon" width="20" height="20" viewBox="0 0 32 32">
                        <path d="M28.7071,19.293,26,16.5859V13a10.0136,10.0136,0,0,0-9-9.9492V1H15V3.0508A10.0136,10.0136,0,0,0,6,13v3.5859L3.2929,19.293A1,1,0,0,0,3,20v3a1,1,0,0,0,1,1h7v.7768a5,5,0,0,0,10,0V24h7a1,1,0,0,0,1-1V20A1,1,0,0,0,28.7071,19.293ZM19,24.7768a3,3,0,0,1-6,0V24h6ZM27,22H5V20.4141L7.707,17.707A1,1,0,0,0,8,17V13a8,8,0,0,1,16,0v4a1,1,0,0,0,.293.707L27,20.4141Z"/>
                    </svg>
                </cds-header-global-action>
                
                ${loginOrLogout}
            </cds-header-global-bar>
        </cds-header>
    `;
}

/**
 * Create Homepage Header (with login) - backward compatibility
 */
export function createHomepageHeader() {
    return createHeader(false);
}

/**
 * Create Admin Header (with side navigation) - backward compatibility
 */
export function createAdminHeader() {
    return createHeader(true);
}

// Made with Bob
