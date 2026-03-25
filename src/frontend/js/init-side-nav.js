/*
 *
 *    Copyright IBM Corp. 2023
 *
 */

/**
 * Initialize side navigation - ensure it starts collapsed
 * The hamburger button and side nav communicate via custom events automatically.
 * We just need to ensure the side nav starts in the collapsed state.
 */
export function initSideNavToggle() {
    // Wait for web components to be defined
    setTimeout(() => {
        const sideNav = document.querySelector('cds-side-nav');
        
        if (sideNav) {
            // Set expanded property to false (not the attribute)
            // The web component uses a boolean property, not a string attribute
            sideNav.expanded = false;
            console.log('Side nav initialized - collapsed by default');
        } else {
            console.error('Could not find side nav');
        }
    }, 100);
}

// Made with Bob

