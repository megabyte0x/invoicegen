import type { ReactElement } from 'react';
import { featureCopy } from '../data/siteContent';
import { BackupPanel } from './BackupPanel';
import { CliPanel } from './CliPanel';
import { ClientPanel } from './ClientPanel';
import { FeatureSection } from './FeatureSection';
import { InvoicePanel } from './InvoicePanel';

export function FeatureFlow(): ReactElement {
  return (
    <section className="feature-flow" id="features" aria-labelledby="features-title">
      <div className="feature-heading">
        <p className="section-label">Features</p>
        <h2 id="features-title">Everything stays close to the invoice.</h2>
      </div>

      <FeatureSection copy={featureCopy.drafting} media={<InvoicePanel />} />
      <FeatureSection copy={featureCopy.clients} media={<ClientPanel />} reversed />
      <FeatureSection copy={featureCopy.cli} media={<CliPanel />} />
      <FeatureSection copy={featureCopy.backup} media={<BackupPanel />} reversed />
    </section>
  );
}
