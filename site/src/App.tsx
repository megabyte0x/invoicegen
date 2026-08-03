import type { ReactElement } from 'react';
import { FAQ } from './components/FAQ';
import { DefinitionSection, ResourcesSection } from './components/CrawlableSections';
import { FeatureFlow } from './components/FeatureFlow';
import { Footer } from './components/Footer';
import { Header } from './components/Header';
import { Hero } from './components/Hero';
import { Overview } from './components/Overview';
import type { ReleaseInfo } from './data/siteContent';
import { useLatestRelease } from './hooks/useLatestRelease';
import { useTheme } from './hooks/useTheme';

interface HomepageProps {
  readonly release: ReleaseInfo;
  readonly onToggleTheme: () => void;
}

export function Homepage({ release, onToggleTheme }: HomepageProps): ReactElement {
  return (
    <>
      <Header onToggleTheme={onToggleTheme} downloadUrl={release.downloadUrl} />
      <main id="top">
        <Hero release={release} />
        <Overview />
        <DefinitionSection />
        <FeatureFlow />
        <FAQ />
        <ResourcesSection />
      </main>
      <Footer />
    </>
  );
}

export function App(): ReactElement {
  const { toggleTheme } = useTheme();
  const release = useLatestRelease();
  return <Homepage release={release} onToggleTheme={toggleTheme} />;
}
