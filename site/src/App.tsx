import type { ReactElement } from 'react';
import { FAQ } from './components/FAQ';
import { FeatureFlow } from './components/FeatureFlow';
import { Footer } from './components/Footer';
import { Header } from './components/Header';
import { Hero } from './components/Hero';
import { Overview } from './components/Overview';
import { useLatestRelease } from './hooks/useLatestRelease';
import { useTheme } from './hooks/useTheme';

export function App(): ReactElement {
  const { toggleTheme } = useTheme();
  const release = useLatestRelease();

  return (
    <>
      <Header onToggleTheme={toggleTheme} downloadUrl={release.downloadUrl} />
      <main id="top">
        <Hero release={release} />
        <Overview />
        <FeatureFlow />
        <FAQ />
      </main>
      <Footer />
    </>
  );
}
