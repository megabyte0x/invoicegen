import type { ReactElement } from 'react';
import { agentPrompt, brandName, facts } from '../data/siteContent';
import { useCopyToClipboard } from '../hooks/useCopyToClipboard';

export function Overview(): ReactElement {
  const { copiedId, copy } = useCopyToClipboard();
  const copyButtonLabel = copiedId === 'agent-setup-prompt' ? 'Copied' : 'Copy';

  return (
    <section className="overview-section" id="overview" aria-labelledby="overview-title">
      <div className="overview-copy">
        <p className="section-label">Overview</p>
        <h2 id="overview-title">A native invoice workspace without a service account.</h2>
        <p>
          {brandName} keeps invoice data on your Mac while giving you enough structure for real client work: contacts, projects, line items, due
          dates, tax, payment notes, exports, backups, and a Rust CLI that reads the same local store.
        </p>
      </div>

      <dl className="fact-list" aria-label={`${brandName} facts`}>
        {facts.map((fact) => (
          <div key={fact.id}>
            <dt>{fact.label}</dt>
            <dd>{fact.value}</dd>
          </div>
        ))}
      </dl>

      <div className="agent-prompt-box">
        <div className="agent-prompt-header">
          <span>Agent setup</span>
        </div>
        <div className="agent-prompt-body">
          <code id="agent-setup-prompt">{agentPrompt}</code>
          <button
            className={`copy-prompt-btn${copiedId === 'agent-setup-prompt' ? ' copied' : ''}`}
            type="button"
            onClick={() => void copy('agent-setup-prompt', agentPrompt)}
            aria-label="Copy agent prompt"
            title="Copy prompt"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M8 8h10v12H8z" />
              <path d="M6 16H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1" />
            </svg>
            <span>{copyButtonLabel}</span>
          </button>
        </div>
      </div>
    </section>
  );
}
