import type { ReactElement } from 'react';
import { assetPaths, brandName, navItems } from '../data/siteContent';

interface HeaderProps {
  readonly downloadUrl: string;
  readonly onToggleTheme: () => void;
}

export function Header({ downloadUrl, onToggleTheme }: HeaderProps): ReactElement {
  return (
    <header className="site-header" aria-label="Primary navigation">
      <a className="brand" href="#top" aria-label={`${brandName} home`}>
        <span className="brand-mark" aria-hidden="true">
          <img src={assetPaths.logo} alt="" width="32" height="32" />
        </span>
        <span>{brandName}</span>
      </a>
      <nav className="nav-links">
        {navItems.map((item) => (
          <a key={item.id} href={item.href}>
            {item.label}
          </a>
        ))}
        <a className="nav-download" href={downloadUrl}>
          Download
        </a>
        <button className="theme-toggle-btn" type="button" onClick={onToggleTheme} aria-label="Toggle dark/light mode" title="Toggle theme">
          <svg className="sun-icon" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
          </svg>
          <svg className="moon-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" strokeLinejoin="round" />
          </svg>
        </button>
      </nav>
    </header>
  );
}
