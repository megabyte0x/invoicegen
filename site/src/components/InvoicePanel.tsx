import type { ReactElement } from 'react';

export function InvoicePanel(): ReactElement {
  return (
    <div className="native-panel invoice-panel" aria-label="Invoice draft preview">
      <div className="mini-toolbar">
        <span>INV-2026-0018</span>
        <span className="mock-button">Preview PDF</span>
      </div>
      <div className="invoice-sheet">
        <div>
          <strong>Blue Peak Consulting</strong>
          <span>100 Pine Street</span>
          <span>San Francisco, CA</span>
        </div>
        <div className="invoice-stamp">Invoice</div>
        <dl>
          <div>
            <dt>Issue</dt>
            <dd>Jun 04, 2026</dd>
          </div>
          <div>
            <dt>Due</dt>
            <dd>Jul 04, 2026</dd>
          </div>
          <div>
            <dt>Total</dt>
            <dd>$3,861.00</dd>
          </div>
        </dl>
        <table>
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th scope="col">Qty</th>
              <th scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Design</td>
              <td>24</td>
              <td>$2,040</td>
            </tr>
            <tr>
              <td>Development</td>
              <td>16</td>
              <td>$1,200</td>
            </tr>
            <tr>
              <td>Content</td>
              <td>8</td>
              <td>$360</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}
