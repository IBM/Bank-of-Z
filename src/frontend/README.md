# CICS Banking Sample Application - Vanilla JavaScript Frontend (Static HTML)

A zero-dependency vanilla JavaScript implementation of the CICS Banking Sample Application frontend using **static HTML pages** and Carbon Design System Web Components.

## 🎯 Overview

This is a complete rewrite of the React-based frontend using:
- **Static HTML Pages** (no router, traditional navigation)
- **Vanilla JavaScript** (ES6 modules)
- **Carbon Web Components** (loaded via CDN)
- **Native Fetch API** (no axios)
- **Zero build process** (no webpack, babel, or bundlers)
- **Zero npm dependencies** (only Node.js for dev server)

## ✨ Key Features

- ✅ **Zero Dependencies**: No npm packages required at runtime
- ✅ **Static HTML Pages**: Each page is a separate HTML file with traditional navigation
- ✅ **Carbon Design System**: Full IBM Carbon UI components via Web Components
- ✅ **Modern JavaScript**: ES6 modules, async/await, native fetch API
- ✅ **No Build Process**: Files are served directly, no compilation needed
- ✅ **Same User Experience**: Maintains all functionality from React version
- ✅ **Easy Deployment**: Can be served by any static web server

## 📁 Project Structure

```
src/bank-application-frontend-vanilla-static/
├── index.html                  # Home page
├── admin.html                  # Admin control panel
├── customer-create.html        # Create customer page
├── customer-details.html       # View/update customer page
├── customer-delete.html        # Delete customer page
├── account-create.html         # Create account page
├── account-details.html        # View/update account page
├── account-delete.html         # Delete account page
├── config.js                   # Application configuration
├── server.js                   # Simple Node.js HTTP server
├── package.json                # Minimal package.json (no dependencies)
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

## 🚀 Quick Start

### Prerequisites

- Node.js 14+ (only for development server)
- Backend API running on http://localhost:8080

### Installation

No installation required! Just start the server:

```bash
cd src/bank-application-frontend-vanilla-static
node server.js
```

Or use npm scripts:

```bash
npm start
# or
npm run dev
```

The application will be available at: **http://localhost:3000**

### Custom Port

```bash
PORT=8000 node server.js
```

## 📄 Pages

### Home Page (`index.html`)
- Welcome screen with tabs (About, User Guide)
- Login mechanism (navigates to Admin page)
- Traditional link: Click user icon to go to admin.html

### Admin Page (`admin.html`)
- Control panel with links to all functions
- Customer services menu
- Account services menu
- Traditional links to all other pages

### Customer Management
- **Create** (`customer-create.html`): Form to create new customers
- **Details** (`customer-details.html`): Search and view customer details with accounts
- **Delete** (`customer-delete.html`): Search and delete customers

### Account Management
- **Create** (`account-create.html`): Form to create new accounts
- **Details** (`account-details.html`): Search and view account details
- **Delete** (`account-delete.html`): Search and delete accounts

## 🔧 Configuration

Edit `config.js` to change API endpoints:

```javascript
export const config = {
    api: {
        customerUrl: 'http://localhost:8080/customer',
        accountUrl: 'http://localhost:8080/account'
    },
    defaults: {
        sortCode: '987654'
    }
};
```

## 🎨 Styling

### Carbon Design System

The application uses Carbon Design System with:

1. **Carbon Styles**: Loaded locally from `css/carbon-styles.min.css` (663KB, downloaded from unpkg CDN)
2. **Carbon Web Components**: Loaded via IBM CDN using component-specific imports

Each HTML page imports only the Carbon components it needs:

```html
<!-- Component-specific imports from IBM CDN -->
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/breadcrumb.min.js"></script>
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/button.min.js"></script>
<script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/text-input.min.js"></script>
<!-- etc. -->
```

**Components Used:**
- `ui-shell.min.js` - Header, side navigation, and shell components
- `breadcrumb.min.js` - Navigation breadcrumbs
- `button.min.js` - Buttons and actions
- `tabs.min.js` - Tab navigation
- `text-input.min.js` - Text input fields
- `dropdown.min.js` - Dropdown selectors
- `date-picker.min.js` - Date selection
- `number-input.min.js` - Numeric input fields
- `modal.min.js` - Modal dialogs

The application uses Carbon's **g100** (dark) theme. Customize in `css/carbon-overrides.css`:

```css
:root {
    --cds-background: #161616;
    --cds-layer: #262626;
    --cds-text-primary: #f4f4f4;
    /* ... more theme variables */
}
```

### Custom Styles

- `css/main.css`: Global styles, layout, forms, tables
- `css/pages.css`: Page-specific styles
- `css/carbon-overrides.css`: Carbon component customizations

## 🔌 API Integration

The application expects a REST API with these endpoints:

### Customer Endpoints
- `GET /customer` - Get all customers
- `GET /customer/:id` - Get customer by ID
- `POST /customer` - Create customer
- `PUT /customer/:id` - Update customer
- `DELETE /customer/:id` - Delete customer

### Account Endpoints
- `GET /account` - Get all accounts
- `GET /account/:id` - Get account by ID
- `GET /account?customerNumber=:id` - Get accounts by customer
- `POST /account` - Create account
- `PUT /account/:id` - Update account
- `DELETE /account/:id` - Delete account

## 🚢 Deployment

### Option 1: Node.js Server (Included)

```bash
node server.js
```

### Option 2: Any Static Web Server

Since there are no build steps, you can serve the files with any web server:

```bash
# Python
python -m http.server 3000

# PHP
php -S localhost:3000

# npx (if you have Node.js)
npx serve .

# Apache/Nginx
# Just point document root to this directory
```

### Option 3: Production Web Server

Configure your web server (Apache, Nginx, etc.) to serve static files from this directory.

Example Nginx configuration:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/bank-application-frontend-vanilla-static;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## 📊 Comparison with React Version

| Feature | React Version | Vanilla Static Version |
|---------|--------------|----------------------|
| Dependencies | 46 packages | 0 packages |
| Bundle Size | ~2MB | ~50KB (excluding Carbon CDN) |
| Build Time | ~30 seconds | 0 seconds (no build) |
| Dev Server Start | ~5 seconds | <1 second |
| Navigation | react-router (SPA) | Static HTML pages |
| Page Load | Client-side routing | Traditional page loads |
| Browser Support | Modern browsers | Modern browsers |
| Carbon Design | @carbon/react | Carbon Web Components |
| HTTP Client | axios | Native fetch() |
| State Management | React state | DOM + local variables |

## 🔄 Navigation Approach

Unlike the router-based version, this implementation uses **traditional HTML navigation**:

- Each page is a separate HTML file
- Navigation uses standard `<a href="page.html">` links
- Full page reload on navigation (traditional web behavior)
- No client-side routing or hash-based URLs
- Simpler mental model, easier to understand
- Better for SEO and accessibility
- Works without JavaScript for basic navigation

## 🐛 Troubleshooting

### Port Already in Use

```bash
PORT=3001 node server.js
```

### CORS Issues

Ensure your backend API has CORS enabled for `http://localhost:3000`

### Carbon Components Not Loading

1. Check your internet connection - Carbon Web Components are loaded from IBM CDN
2. Verify the CDN URLs are accessible: `https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/`
3. Check browser console for 404 errors or CORS issues
4. Ensure you're importing the correct component files for the components used on each page

### API Connection Failed

1. Verify backend is running on http://localhost:8080
2. Check `config.js` for correct API URLs
3. Check browser console for errors

## 📝 Development

### Adding a New Page

1. Create new HTML file (e.g., `my-page.html`)
2. Copy structure from existing page
3. Import necessary modules in inline script
4. Add navigation links from other pages

Example:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Page - CBSA</title>
    <link rel="stylesheet" href="css/carbon-styles.min.css">
    <link rel="stylesheet" href="css/main.css">
</head>
<body>
    <div id="header-container"></div>
    <div class="cds--content">
        <!-- Your content here -->
    </div>
    
    <!-- Carbon Web Components - Component-specific imports -->
    <script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/breadcrumb.min.js"></script>
    <script type="module" src="https://1.www.s81c.com/common/carbon/web-components/version/v2.47.0/button.min.js"></script>
    <!-- Add other components as needed -->
    
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

## 🆚 Differences from Router Version

The main differences from `bank-application-frontend-vanilla-router`:

1. **Navigation**: Static HTML pages instead of hash-based routing
2. **Page Structure**: Each page is self-contained HTML file
3. **No Router**: Removed `js/router.js` completely
4. **Traditional Links**: Uses `<a href="page.html">` instead of `window.location.hash`
5. **Page Loads**: Full page reload on navigation (traditional web behavior)
6. **Simpler**: Easier to understand and maintain
7. **Better SEO**: Search engines can index individual pages
8. **Accessibility**: Works better with screen readers and assistive technologies

## 📜 License

Apache-2.0

## 🤝 Contributing

See CONTRIBUTING.md in the root directory.

## 📞 Support

For issues and questions, please use the GitHub issue tracker.

---

**Built with ❤️ using Vanilla JavaScript, Static HTML, and Carbon Design System**