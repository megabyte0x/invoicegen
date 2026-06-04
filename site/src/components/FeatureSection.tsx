import type { ReactElement, ReactNode } from 'react';
import type { FeatureCopy } from '../data/siteContent';

interface FeatureSectionProps {
  readonly copy: FeatureCopy;
  readonly media: ReactNode;
  readonly reversed?: boolean;
}

export function FeatureSection({ copy, media, reversed = false }: FeatureSectionProps): ReactElement {
  const className = reversed ? 'feature-row reverse' : 'feature-row';

  return (
    <article className={className}>
      <div className="feature-copy">
        <p className="section-label">{copy.label}</p>
        <h3>{copy.title}</h3>
        <p>{copy.description}</p>
        <ul className="feature-points">
          {copy.points.map((point) => (
            <li key={point}>{point}</li>
          ))}
        </ul>
      </div>
      {media}
    </article>
  );
}
