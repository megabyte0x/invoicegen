import type { ReactElement } from 'react';
import { agentPrompt, assetPaths, brandName, type ReleaseInfo } from '../data/siteContent';
import { useCopyToClipboard } from '../hooks/useCopyToClipboard';

interface HeroProps {
  readonly release: ReleaseInfo;
}

export function Hero({ release }: HeroProps): ReactElement {
  const { copiedId, copy } = useCopyToClipboard();
  const copyButtonLabel = copiedId === 'hero-agent-prompt' ? 'Copied' : 'Copy prompt';

  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero-copy">
        <img className="hero-icon" src={assetPaths.logo} alt="" width="84" height="84" />
        <p className="lead-line">{brandName} for macOS.</p>
        <h1 id="hero-title">Local-first invoices, built for your Mac.</h1>
        <p className="hero-subtitle">
          A focused native workspace for clients, projects, payment details, invoices, and PDF-ready exports. No account, no hosted backend.
        </p>
        <div className="actions" aria-label="Primary actions">
          <a className="button primary" href={release.downloadUrl}>
            <span>Download for macOS</span>
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M5 12h14" />
              <path d="m12 5 7 7-7 7" />
            </svg>
          </a>
          <button className="button secondary" type="button" onClick={() => void copy('hero-agent-prompt', agentPrompt)}>
            {copyButtonLabel}
          </button>
        </div>
        <div className="download-meta">
          <span>{release.versionLabel}</span>
          <span>macOS 14.0+ required</span>
        </div>
      </div>

      <figure className="hero-window" aria-label={`${brandName} product preview`}>
        <picture className="hero-window-picture">
          <source type="image/webp" srcSet={assetPaths.previewSrcSet} sizes={assetPaths.previewSizes} />
          <source type="image/png" srcSet={assetPaths.previewFallbackSrcSet} sizes={assetPaths.previewSizes} />
          <img
            src={assetPaths.preview}
            srcSet={assetPaths.previewFallbackSrcSet}
            sizes={assetPaths.previewSizes}
            alt="InvoiceGen macOS app window showing invoice lists, client revenue charts, and native sidebar tabs"
            width="1536"
            height="1024"
            fetchPriority="high"
          />
        </picture>
      </figure>
    </section>
  );
}
