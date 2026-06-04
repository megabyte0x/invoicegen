import type { ReactElement } from 'react';
import { clientNames } from '../data/siteContent';

export function ClientPanel(): ReactElement {
  return (
    <div className="native-panel client-panel" aria-label="Client and project preview">
      <div className="mini-sidebar">
        {clientNames.map((client) => (
          <span key={client.id} className={client.active ? 'active' : undefined}>
            {client.name}
          </span>
        ))}
      </div>
      <div className="client-detail">
        <strong>Blue Peak Consulting</strong>
        <dl>
          <div>
            <dt>Contact</dt>
            <dd>Alex Morgan</dd>
          </div>
          <div>
            <dt>Email</dt>
            <dd>alex@typepeak.com</dd>
          </div>
          <div>
            <dt>Project</dt>
            <dd>Website redesign</dd>
          </div>
          <div>
            <dt>Status</dt>
            <dd>Active</dd>
          </div>
        </dl>
      </div>
    </div>
  );
}
