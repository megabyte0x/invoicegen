(function () {
  const root = document.documentElement;
  const media = window.matchMedia('(prefers-color-scheme: dark)');

  function currentTheme() {
    let stored;
    try {
      stored = localStorage.getItem('theme');
    } catch {
      stored = null;
    }
    return stored === 'dark' || stored === 'light'
      ? stored
      : media.matches ? 'dark' : 'light';
  }

  function apply(theme, persist) {
    root.classList.toggle('dark', theme === 'dark');
    root.style.colorScheme = theme;
    if (persist) {
      try {
        localStorage.setItem('theme', theme);
      } catch {
        // The selected theme still applies when storage is unavailable.
      }
    }
    document.querySelectorAll('[data-theme-label]').forEach((label) => {
      label.textContent = theme === 'dark' ? 'Light theme' : 'Dark theme';
    });
  }

  apply(currentTheme(), false);
  document.addEventListener('DOMContentLoaded', function () {
    apply(currentTheme(), false);
    document.querySelectorAll('[data-theme-toggle]').forEach((button) => {
      button.addEventListener('click', function () {
        apply(root.classList.contains('dark') ? 'light' : 'dark', true);
      });
    });
  });
})();
