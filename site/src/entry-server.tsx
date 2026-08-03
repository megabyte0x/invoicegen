import { renderToString } from 'react-dom/server';
import { Homepage } from './App';
import { fallbackRelease } from './data/siteContent';

export function renderHomepage(): string {
  return renderToString(
    <Homepage release={fallbackRelease} onToggleTheme={() => undefined} />,
  );
}
