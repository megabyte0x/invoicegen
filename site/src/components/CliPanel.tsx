import type { ReactElement } from 'react';

export function CliPanel(): ReactElement {
  return (
    <div className="terminal-panel" aria-label="InvoiceGen CLI examples">
      <div className="terminal-title">zsh</div>
      <div className="terminal-row">
        <span className="prompt">$</span>
        <code>invoicegen invoice create --client &quot;Blue Peak Consulting&quot;</code>
      </div>
      <div className="terminal-row success">
        <span className="prompt">✓</span>
        <code>Created invoice INV-2026-0018</code>
      </div>
      <div className="terminal-row">
        <span className="prompt">$</span>
        <code>invoicegen invoice list --status sent</code>
      </div>
      <pre>{`ID             Client                  Total      Due
INV-2026-0018  Blue Peak Consulting    $3,861.00  2026-07-04
INV-2026-0017  Northwind Labs          $1,750.00  2026-06-20`}</pre>
    </div>
  );
}
