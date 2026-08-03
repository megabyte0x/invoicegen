import type { MouseEvent, ReactElement } from 'react';
import { useState } from 'react';
import { faqItems } from '../data/siteContent';

export function FAQ(): ReactElement {
  const [openItemId, setOpenItemId] = useState<string | null>(null);

  function toggleItem(event: MouseEvent<HTMLButtonElement>, itemId: string, isOpen: boolean): void {
    const button = event.currentTarget;
    const topBefore = button.getBoundingClientRect().top;

    setOpenItemId(isOpen ? null : itemId);

    requestAnimationFrame(() => {
      if (!button.isConnected) return;

      const delta = button.getBoundingClientRect().top - topBefore;
      if (delta !== 0) window.scrollBy(0, delta);
    });
  }

  return (
    <section className="faq-section" id="faq" aria-labelledby="faq-title">
      <div className="feature-heading">
        <p className="section-label">FAQ</p>
        <h2 id="faq-title">Practical details before you install.</h2>
      </div>
      <div className="faq-list">
        {faqItems.map((item) => {
          const isOpen = openItemId === item.id;
          const answerId = `${item.id}-answer`;

          return (
            <div className={`faq-item${isOpen ? ' active' : ''}`} key={item.id}>
              <button
                className="faq-question"
                type="button"
                aria-expanded={isOpen}
                aria-controls={answerId}
                onClick={(event) => toggleItem(event, item.id, isOpen)}
              >
                <span>{item.question}</span>
                <span className="faq-icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24">
                    <path d="m6 9 6 6 6-6" />
                  </svg>
                </span>
              </button>
              <div className="faq-answer" id={answerId}>
                <div className="faq-answer-inner">{item.answer}</div>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
