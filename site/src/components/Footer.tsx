import type { ReactElement } from 'react';
import { assetPaths } from '../data/siteContent';

export function Footer(): ReactElement {
  return (
    <footer>
      <div className="footer-inner">
        <div className="footer-brand">
          <img src={assetPaths.logo} alt="" width="28" height="28" />
          <span>InvoiceGen</span>
        </div>
        <nav className="footer-links" aria-label="Footer navigation">
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a className="github-link" href="https://github.com/megabyte0x/invoicegen" target="_blank" rel="noopener">
            <svg className="github-icon" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M12 .5a12 12 0 0 0-3.8 23.39c.6.11.82-.26.82-.58v-2.08c-3.34.73-4.04-1.42-4.04-1.42-.55-1.39-1.34-1.76-1.34-1.76-1.09-.74.08-.73.08-.73 1.21.09 1.85 1.24 1.85 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.24-3.22-.12-.3-.54-1.53.12-3.18 0 0 1.01-.32 3.3 1.23a11.4 11.4 0 0 1 6.01 0c2.29-1.55 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.77.84 1.24 1.91 1.24 3.22 0 4.61-2.81 5.63-5.48 5.92.43.37.81 1.1.81 2.22v3.3c0 .32.22.69.83.57A12 12 0 0 0 12 .5Z" />
            </svg>
            GitHub
          </a>
          <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank" rel="noopener">
            License
          </a>
        </nav>
        <p>&copy; 2026 InvoiceGen. Native macOS invoicing, kept local.</p>
      </div>
    </footer>
  );
}
