import { useEffect, useState } from 'react';
import { fallbackRelease, type ReleaseInfo } from '../data/siteContent';

interface GitHubReleaseAsset {
  readonly browser_download_url?: string;
  readonly name?: string;
}

interface GitHubRelease {
  readonly assets?: readonly GitHubReleaseAsset[];
  readonly tag_name?: string;
}

function buildDownloadUrl(tagName: string, assets: readonly GitHubReleaseAsset[] | undefined): string {
  const dmgAsset = assets?.find((asset) => asset.name?.endsWith('.dmg') && asset.browser_download_url);
  if (dmgAsset?.browser_download_url) {
    return dmgAsset.browser_download_url;
  }

  const versionNumber = tagName.startsWith('v') ? tagName.slice(1) : tagName;
  return `https://github.com/megabyte0x/invoicegen/releases/download/${tagName}/InvoiceGen-${versionNumber}.dmg`;
}

export function useLatestRelease(): ReleaseInfo {
  const [release, setRelease] = useState<ReleaseInfo>(fallbackRelease);

  useEffect(() => {
    const controller = new AbortController();

    async function updateLatestRelease(): Promise<void> {
      try {
        const response = await fetch('https://api.github.com/repos/megabyte0x/invoicegen/releases/latest', {
          signal: controller.signal,
        });

        if (!response.ok) {
          return;
        }

        const data = (await response.json()) as GitHubRelease;
        if (!data.tag_name) {
          return;
        }

        setRelease({
          versionLabel: `Version ${data.tag_name}`,
          downloadUrl: buildDownloadUrl(data.tag_name, data.assets),
        });
      } catch (error) {
        if (!(error instanceof DOMException && error.name === 'AbortError')) {
          return;
        }
      }
    }

    void updateLatestRelease();

    return () => {
      controller.abort();
    };
  }, []);

  return release;
}
