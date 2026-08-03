import type { ReactElement } from 'react';

const invoiceRows = [
  { id: 'INV-2026-0018', client: 'Blue Peak Consulting', total: '$3,861.00', due: '2026-07-04' },
  { id: 'INV-2026-0017', client: 'Northwind Labs', total: '$1,750.00', due: '2026-06-20' },
] as const;

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
      <div className="terminal-output" role="table" aria-label="Sent invoice output">
        <div className="terminal-output-row terminal-output-header" role="row">
          <span role="columnheader">ID</span>
          <span role="columnheader">Client</span>
          <span role="columnheader">Total</span>
          <span role="columnheader">Due</span>
        </div>
        {invoiceRows.map((invoice) => (
          <div className="terminal-output-row" role="row" key={invoice.id}>
            <span role="cell" data-label="ID">{invoice.id}</span>
            <span role="cell" data-label="Client">{invoice.client}</span>
            <span role="cell" data-label="Total">{invoice.total}</span>
            <span role="cell" data-label="Due">{invoice.due}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
