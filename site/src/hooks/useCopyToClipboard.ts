import { useCallback, useEffect, useRef, useState } from 'react';

async function copyWithFallback(text: string): Promise<boolean> {
  if (navigator.clipboard && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (_) {
      // Fall back to the selection-based path below.
    }
  }

  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.left = '-9999px';
  document.body.appendChild(textarea);
  textarea.select();

  try {
    return document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    textarea.remove();
  }
}

export function useCopyToClipboard(resetDelayMs = 1400): {
  readonly copiedId: string | null;
  readonly copy: (id: string, text: string) => Promise<boolean>;
} {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const resetTimerRef = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (resetTimerRef.current !== null) {
        window.clearTimeout(resetTimerRef.current);
      }
    };
  }, []);

  const copy = useCallback(
    async (id: string, text: string): Promise<boolean> => {
      const copied = await copyWithFallback(text);

      if (resetTimerRef.current !== null) {
        window.clearTimeout(resetTimerRef.current);
      }

      setCopiedId(copied ? id : null);
      resetTimerRef.current = window.setTimeout(() => {
        setCopiedId(null);
      }, resetDelayMs);

      return copied;
    },
    [resetDelayMs],
  );

  return { copiedId, copy };
}
