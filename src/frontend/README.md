# Bank of Z Frontend — Vanilla JavaScript (Static HTML)

A zero-dependency vanilla JavaScript frontend for the Bank of Z Sample Application, using static HTML pages and Carbon Design System Web Components.

## Overview

- **Static HTML pages** — no router, traditional multi-page navigation
- **Vanilla JavaScript** (ES6 modules)
- **Carbon Web Components** loaded via IBM CDN
- **Native Fetch API** — no additional HTTP library
- **No build process** — files are served directly, no compilation needed
- **No runtime dependencies** — served by any static web server or container

## Key Features

- **Zero Dependencies**: No packages required at runtime or build time
- **Static HTML Pages**: Each page is a separate HTML file with traditional navigation
- **Carbon Design System**: Full IBM Carbon UI components via Web Components
- **Modern JavaScript**: ES6 modules, async/await, native fetch API
- **Easy Deployment**: Served by any static web server or OpenShift/Kubernetes ingress

## Project Structure

```
src/frontend/
├── index.html                  # Home page
├── admin.html                  # Admin control panel
├── customer-create.html        # Create customer page
├── customer-details.html       # View/update customer page
├── customer-delete.html        # Delete customer page
├── account-create.html         # Create account page
├── account-details.html        # View/update account page
├── account-delete.html         # Delete account page
├── config.js                   # Application configuration (API endpoints)
├── css/
│   ├── main.css               # Global styles
│   ├── pages.css              # Page-specific styles
│   └── carbon-overrides.css   # Carbon theme customizations
├── js/
│   ├── api.js                 # API service layer (fetch)
│   ├── utils.js               # Utility functions
│   └── components/
│       └── headers.js         # Reusable header components
└── assets/
    └── images/                # Application images
```

## Pages

### Home Page (`index.html`)
- Welcome screen with tabs (About, User Guide)
- Login mechanism that navigates to the Admin page

### Admin Page (`admin.html`)
- Control panel with links to all functions
- Customer services menu
- Account services menu

### Customer Management
- **Create** (`customer-create.html`): Form to create new customers
- **Details** (`customer-details.html`): Search and view customer details with accounts
- **Delete** (`customer-delete.html`): Search and delete customers

### Account Management
- **Create** (`account-create.html`): Form to create new accounts
- **Details** (`account-details.html`): Search and view account details
- **Delete** (`account-delete.html`): Search and delete accounts

## Configuration

Edit `config.js` to point at your backend API:

```javascript
export const config = {
    api: {
        customerUrl: 'http://localhost:9080/customer',
        accountUrl: 'http://localhost:9080/account'
    },
    defaults: {
        sortCode: '987654'
    }
};
```

## Styling

### Carbon Design System

The application uses Carbon Design System with:

1. **Carbon Styles**: Loaded locally from `css/carbon-styles.min.css`
2. **Carbon Web Components**: Loaded via IBM CDN using component-specific imports

Each HTML page imports only the Carbon components it needs:

```html
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/breadcrumb.min.js"></script>
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/button.min.js"></script>
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/text-input.min.js"></script>
```

**Components used:**
- `ui-shell.min.js` — Header, side navigation, and shell components
- `breadcrumb.min.js` — Navigation breadcrumbs
- `button.min.js` — Buttons and actions
- `tabs.min.js` — Tab navigation
- `text-input.min.js` — Text input fields
- `dropdown.min.js` — Dropdown selectors
- `date-picker.min.js` — Date selection
- `number-input.min.js` — Numeric input fields
- `modal.min.js` — Modal dialogs

The application uses Carbon's **g100** (dark) theme. Customise in `css/carbon-overrides.css`:

```css
:root {
    --cds-background: #161616;
    --cds-layer: #262626;
    --cds-text-primary: #f4f4f4;
    /* ... more theme variables */
}
```

### Custom Styles

- `css/main.css` — Global styles, layout, forms, tables
- `css/pages.css` — Page-specific styles
- `css/carbon-overrides.css` — Carbon component customizations

## API Integration

The application expects a REST API with these endpoints:

### Customer Endpoints
- `GET /customer` — Get all customers
- `GET /customer/:id` — Get customer by ID
- `POST /customer` — Create customer
- `PUT /customer/:id` — Update customer
- `DELETE /customer/:id` — Delete customer

### Account Endpoints
- `GET /account` — Get all accounts
- `GET /account/:id` — Get account by ID
- `GET /account?customerNumber=:id` — Get accounts by customer
- `POST /account` — Create account
- `PUT /account/:id` — Update account
- `DELETE /account/:id` — Delete account

## Deployment

The frontend is plain static HTML — serve the contents of `src/frontend/` with any web server or container.

For local development with Docker, see [`dev/README.md`](../../dev/README.md).

Ensure your backend API has CORS enabled for the origin serving the frontend, or configure a reverse proxy to route API requests to the backend on the same origin.

## Navigation Approach

This implementation uses **traditional HTML navigation**:

- Each page is a separate HTML file
- Navigation uses standard `<a href="page.html">` links
- Full page reload on navigation (traditional web behaviour)
- No client-side routing or hash-based URLs
- Works without JavaScript for basic navigation

## Development

### Adding a New Page

1. Create a new HTML file (e.g., `my-page.html`)
2. Copy the structure from an existing page
3. Import only the Carbon components needed by that page
4. Add navigation links from other pages

Example skeleton:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Page - Bank of Z</title>
    <link rel="stylesheet" href="css/carbon-styles.min.css">
    <link rel="stylesheet" href="css/main.css">
</head>
<body>
    <div id="header-container"></div>
    <div class="cds--content">
        <!-- Your content here -->
    </div>

    <!-- Carbon Web Components — import only what this page uses -->
    <script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/breadcrumb.min.js"></script>
    <script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/button.min.js"></script>

    <script type="module">
        import { createAdminHeader } from './js/components/headers.js';
        document.getElementById('header-container').innerHTML = createAdminHeader();
    </script>
</body>
</html>
```

### Adding API Methods

Add methods to `js/api.js`:

```javascript
async myNewMethod(data) {
    return this.request('/my-endpoint', {
        method: 'POST',
        body: JSON.stringify(data)
    });
}
```

## Troubleshooting

### CORS Issues

Ensure the backend API has CORS enabled for the origin serving the frontend, or configure a reverse proxy to route API calls to the backend on the same origin.

### Carbon Components Not Loading

1. Check internet connectivity — Carbon Web Components are loaded from IBM CDN
2. Verify CDN URLs are accessible: `https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/`
3. Check the browser console for 404 errors or CORS issues
4. Confirm you are importing the correct component file for each component used on the page

### API Connection Failed

1. Verify the backend is running and accessible
2. Check `config.js` for correct API URLs
3. Check the browser console for errors

## License

Apache-2.0

## Contributing

See `CONTRIBUTING.md` in the root directory.

---

Built with Vanilla JavaScript, Static HTML, and Carbon Design System.
