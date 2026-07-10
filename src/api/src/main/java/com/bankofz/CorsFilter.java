package com.bankofz;

import javax.servlet.*;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * CORS filter for Bank of Z API.
 * Allows cross-origin requests from the frontend Liberty server on HTTPS 9444.
 * Registered in web.xml — no external dependencies required.
 */
public class CorsFilter implements Filter {

    @Override
    public void init(FilterConfig filterConfig) {}

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  req  = (HttpServletRequest)  request;
        HttpServletResponse resp = (HttpServletResponse) response;

        String origin = req.getHeader("Origin");
        if (origin != null) {
            resp.setHeader("Access-Control-Allow-Origin",      origin);
            resp.setHeader("Access-Control-Allow-Credentials", "true");
            resp.setHeader("Access-Control-Allow-Methods",     "GET, POST, PUT, DELETE, OPTIONS");
            resp.setHeader("Access-Control-Allow-Headers",     "Content-Type, Authorization, Accept");
            resp.setHeader("Access-Control-Max-Age",           "3600");
        }

        // Handle preflight — return 200 immediately without hitting the API
        if ("OPTIONS".equalsIgnoreCase(req.getMethod())) {
            resp.setStatus(HttpServletResponse.SC_OK);
            return;
        }

        chain.doFilter(request, response);
    }

    @Override
    public void destroy() {}
}
