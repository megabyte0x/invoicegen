import { Analytics } from '@vercel/analytics/react';
import React from 'react';
import { createRoot, hydrateRoot } from 'react-dom/client';
import { App } from './App';
import './styles.css';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('InvoiceGen app root was not found');
}

hydrateRoot(
  rootElement,
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

const analyticsElement = document.getElementById('analytics-root');
if (analyticsElement) {
  createRoot(analyticsElement).render(<Analytics />);
}
