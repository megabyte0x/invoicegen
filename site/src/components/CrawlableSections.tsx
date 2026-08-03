import type { ReactElement } from 'react';

export function DefinitionSection(): ReactElement {
  return (
    <section className="overview-section" aria-labelledby="what-is-invoicegen">
      <div className="overview-copy">
        <p className="section-label">Definition</p>
        <h2 id="what-is-invoicegen">What is InvoiceGen?</h2>
        <p>
          InvoiceGen is a local-first invoicing workspace for macOS that combines a native Swift app with a Rust command-line interface. It is
          designed for freelancers, consultants, and small teams who want to manage clients, projects, invoice line items, due dates, payment
          details, taxes, notes, backups, and PDF-ready invoice exports without creating a cloud account or storing billing data on a hosted
          service. The macOS app and CLI use the same local store format, so users and AI agents can inspect, create, list, render, export, and
          restore invoice data through scripts while preserving compatibility with the desktop app. InvoiceGen is open source under the Apache
          2.0 license, targets macOS 14 Sonoma or newer, and publishes its source, releases, and agent workflow at github.com/megabyte0x/invoicegen
          and invoicegen.megabyte.sh/SKILL.md. This combination differentiates it from browser-only invoice generators and cloud accounting tools
          by emphasizing privacy, local ownership, and scriptable workflows.
        </p>
      </div>
      <dl className="fact-list" aria-label="InvoiceGen citation facts">
        <div>
          <dt>Cloud</dt>
          <dd>No account or hosted invoice store required</dd>
        </div>
        <div>
          <dt>CLI</dt>
          <dd>Script invoice, client, project, render, export, and restore workflows</dd>
        </div>
        <div>
          <dt>Source</dt>
          <dd>github.com/megabyte0x/invoicegen</dd>
        </div>
        <div>
          <dt>Agent skill</dt>
          <dd>invoicegen.megabyte.sh/SKILL.md</dd>
        </div>
      </dl>
    </section>
  );
}

export function ResourcesSection(): ReactElement {
  return (
    <section className="overview-section" id="resources" aria-labelledby="resources-title">
      <div className="overview-copy">
        <p className="section-label">Resources</p>
        <h2 id="resources-title">Indexable guides for local-first invoice generation.</h2>
        <p>
          InvoiceGen publishes focused resources for Rust invoice CLI workflows, privacy-first invoice generation, local-first invoicing,
          invoice backup and restore, open-source invoice generator positioning, Manta and Invoice Ninja alternative submissions, offline Mac
          invoice searches, launch-directory assets, and release notes. These pages give reviewers, directories, and community posts specific
          URLs to cite instead of pointing every backlink at the homepage.
        </p>
      </div>
      <dl className="fact-list" aria-label="InvoiceGen resource pages">
        <div>
          <dt>CLI</dt>
          <dd>
            <a href="/cli">Rust invoice CLI workflows</a>
          </dd>
        </div>
        <div>
          <dt>Privacy</dt>
          <dd>
            <a href="/privacy">Privacy-first invoice generation</a>
          </dd>
        </div>
        <div>
          <dt>Guide</dt>
          <dd>
            <a href="/docs/local-first-invoicing">Local-first invoicing guide</a>
          </dd>
        </div>
        <div>
          <dt>Backup</dt>
          <dd>
            <a href="/docs/backup-restore">Backup and restore invoices</a>
          </dd>
        </div>
        <div>
          <dt>Open source</dt>
          <dd>
            <a href="/open-source-invoice-generator">Open-source invoice generator</a>
          </dd>
        </div>
        <div>
          <dt>Alternative</dt>
          <dd>
            <a href="/alternatives/manta">Manta alternative for Mac invoicing</a>
          </dd>
        </div>
        <div>
          <dt>Invoice Ninja</dt>
          <dd>
            <a href="/alternatives/invoice-ninja">Invoice Ninja alternative for Mac freelancers</a>
          </dd>
        </div>
        <div>
          <dt>Offline Mac</dt>
          <dd>
            <a href="/offline-invoice-generator-mac">Offline invoice generator for Mac</a>
          </dd>
        </div>
        <div>
          <dt>Launch kit</dt>
          <dd>
            <a href="/launch-kit">InvoiceGen launch and directory assets</a>
          </dd>
        </div>
      </dl>
    </section>
  );
}
