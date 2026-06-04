export interface ReleaseInfo {
  readonly versionLabel: string;
  readonly downloadUrl: string;
}

export interface FactItem {
  readonly id: string;
  readonly label: string;
  readonly value: string;
}

export interface FeatureCopy {
  readonly id: string;
  readonly label: string;
  readonly title: string;
  readonly description: string;
  readonly points: readonly string[];
}

export interface FAQItem {
  readonly id: string;
  readonly question: string;
  readonly answer: string;
}

export const assetPaths = {
  logo: '/assets/invoicegen-logo-128.png',
  logoWebp: '/assets/invoicegen-logo-128.webp',
  preview: '/assets/invoicegen-preview.png',
  previewWebp: '/assets/invoicegen-preview.webp',
  previewSrcSet: '/assets/invoicegen-preview-640.webp 640w, /assets/invoicegen-preview-960.webp 960w, /assets/invoicegen-preview-1280.webp 1280w, /assets/invoicegen-preview.webp 1536w',
  previewFallbackSrcSet:
    '/assets/invoicegen-preview-640.png 640w, /assets/invoicegen-preview-960.png 960w, /assets/invoicegen-preview-1280.png 1280w, /assets/invoicegen-preview.png 1536w',
  previewSizes: '(max-width: 720px) calc(100vw - 36px), 1180px',
} as const;

export const releaseVersion = __INVOICEGEN_VERSION__;
export const brandName = 'InvoiceGen';
export const siteUrl = 'https://invoicegen.megabyte.sh';

export const fallbackRelease: ReleaseInfo = {
  versionLabel: `Version v${releaseVersion}`,
  downloadUrl: `https://github.com/megabyte0x/invoicegen/releases/download/v${releaseVersion}/InvoiceGen-${releaseVersion}.dmg`,
};

export const navItems = [
  { id: 'overview', label: 'Overview', href: '#overview' },
  { id: 'features', label: 'Features', href: '#features' },
  { id: 'faq', label: 'FAQ', href: '#faq' },
] as const;

export const facts: readonly FactItem[] = [
  { id: 'storage', label: 'Storage', value: 'Local files on your Mac' },
  { id: 'exports', label: 'Exports', value: 'PDF-ready invoice output' },
  { id: 'automation', label: 'Automation', value: 'Rust CLI, same data model' },
  { id: 'license', label: 'License', value: 'Open source, Apache 2.0' },
];

export const agentPrompt =
  `Install this InvoiceGen skill from ${siteUrl}/SKILL.md, then set up a new invoice.`;

export const featureCopy = {
  drafting: {
    id: 'drafting',
    label: 'Drafting',
    title: 'Draft clean invoices.',
    description:
      'Build invoices with structured numbers, issue dates, due dates, line items, tax, payment details, terms, and notes before exporting a client-ready PDF.',
    points: [
      'Line item quantity, rate, tax, and totals',
      'Draft, sent, paid, overdue, and void statuses',
      'Preview before export',
    ],
  },
  clients: {
    id: 'clients',
    label: 'Clients',
    title: 'Keep clients and projects close.',
    description:
      'Store billing contacts, currencies, project context, default rates, and notes once, then reuse them across invoices without opening a heavier CRM.',
    points: [
      'Client contact details and payment notes',
      'Project-level rates and billing context',
      'Yearly revenue and outstanding balances',
    ],
  },
  cli: {
    id: 'cli',
    label: 'CLI',
    title: 'Automate with the CLI.',
    description:
      'Create invoices, list outstanding balances, render exports, and move data through scripts using a Rust CLI that shares the same store format as the app.',
    points: ['Fast local commands for agent workflows', 'Readable JSON and text output', 'Same data as the native app'],
  },
  backup: {
    id: 'backup',
    label: 'Backup',
    title: 'Back up and restore locally.',
    description:
      'Keep data in files you control. Export a backup before changing machines, restore it when needed, or let normal Mac backups capture the local store.',
    points: ['Export Backup and Restore Backup in Settings', 'CLI export and restore commands', 'No hosted account required'],
  },
} satisfies Record<string, FeatureCopy>;

export const clientNames = [
  { id: 'blue-peak', name: 'Blue Peak Consulting', active: true },
  { id: 'acme', name: 'Acme Design Studio', active: false },
  { id: 'northwind', name: 'Northwind Labs', active: false },
  { id: 'stonefield', name: 'Stonefield Co.', active: false },
] as const;

export const faqItems: readonly FAQItem[] = [
  {
    id: 'privacy',
    question: 'Is my invoicing data sent to any servers?',
    answer: 'No. InvoiceGen is local-first. App data, settings, client records, and exports are processed on your Mac.',
  },
  {
    id: 'pricing',
    question: 'Is there a subscription fee?',
    answer: 'No. InvoiceGen is open source and free to download. There are no billing tiers or paid seats.',
  },
  {
    id: 'macos',
    question: 'What versions of macOS are supported?',
    answer: 'The macOS app requires macOS 14.0 Sonoma or newer.',
  },
  {
    id: 'backup',
    question: 'How do I back up my data?',
    answer:
      'Use Export Backup and Restore Backup in Settings, or run invoicegen store export PATH and invoicegen store restore PATH --force from the CLI. Standard backups like Time Machine can also capture the local application support data.',
  },
];
