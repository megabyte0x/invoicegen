import type { ReactElement } from 'react';
import { assetPaths, brandName } from '../data/siteContent';

const footerGroups = [
  {
    title: 'Product',
    links: [
      { href: '#features', label: 'Features' },
      { href: '#faq', label: 'FAQ' },
      { href: '/cli', label: 'CLI' },
      { href: '/privacy', label: 'Privacy' },
    ],
  },
  {
    title: 'Guides',
    links: [
      { href: '/docs/local-first-invoicing', label: 'Local-first guide' },
      { href: '/docs/backup-restore', label: 'Backup guide' },
      { href: '/launch-kit', label: 'Launch kit' },
      { href: '/changelog', label: 'Changelog' },
    ],
  },
  {
    title: 'Alternatives',
    links: [
      { href: '/alternatives/manta', label: 'Manta alternative' },
      { href: '/alternatives/invoice-ninja', label: 'Invoice Ninja alternative' },
      { href: '/offline-invoice-generator-mac', label: 'Offline Mac' },
      { href: '/open-source-invoice-generator', label: 'Open source' },
    ],
  },
] as const;

export function Footer(): ReactElement {
  return (
    <footer>
      <div className="footer-inner">
        <div className="footer-shell">
          <div className="footer-lede">
            <div className="footer-brand">
              <img src={assetPaths.logo} alt="" width="28" height="28" />
              <span>{brandName}</span>
            </div>
            <p className="footer-summary">Native macOS invoicing with local storage, backup control, and a CLI that speaks the same data model.</p>
            <div className="footer-pills" aria-label="Product highlights">
              <span>Native macOS</span>
              <span>Local-first</span>
              <span>Apache 2.0</span>
            </div>
          </div>
          <div className="footer-grid">
            {footerGroups.map((group) => (
              <nav key={group.title} className="footer-column" aria-label={group.title}>
                <p>{group.title}</p>
                <div className="footer-links">
                  {group.links.map((link) => (
                    <a key={link.href} href={link.href}>
                      {link.label}
                    </a>
                  ))}
                </div>
              </nav>
            ))}
          </div>
        </div>
        <div className="footer-meta">
          <p>&copy; 2026 {brandName}. Native macOS invoice generation, kept local.</p>
          <div className="footer-meta-links">
            <a className="github-link" href="https://github.com/megabyte0x/invoicegen" target="_blank" rel="noopener">
              <svg className="github-icon" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M12 .5a12 12 0 0 0-3.8 23.39c.6.11.82-.26.82-.58v-2.08c-3.34.73-4.04-1.42-4.04-1.42-.55-1.39-1.34-1.76-1.34-1.76-1.09-.74.08-.73.08-.73 1.21.09 1.85 1.24 1.85 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.24-3.22-.12-.3-.54-1.53.12-3.18 0 0 1.01-.32 3.3 1.23a11.4 11.4 0 0 1 6.01 0c2.29-1.55 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.77.84 1.24 1.91 1.24 3.22 0 4.61-2.81 5.63-5.48 5.92.43.37.81 1.1.81 2.22v3.3c0 .32.22.69.83.57A12 12 0 0 0 12 .5Z" />
              </svg>
              GitHub
            </a>
            <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank" rel="noopener">
              License
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
