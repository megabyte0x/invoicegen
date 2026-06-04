import type { ReactElement } from 'react';

export function BackupPanel(): ReactElement {
  return (
    <div className="native-panel backup-panel" aria-label="Backup settings preview">
      <div className="settings-row">
        <div>
          <strong>Backup your data</strong>
          <span>Create a backup of your InvoiceGen data.</span>
        </div>
        <span className="mock-button">Create Backup...</span>
      </div>
      <div className="settings-row">
        <div>
          <strong>Restore from backup</strong>
          <span>Restore your data from a backup file.</span>
        </div>
        <span className="mock-button">Restore...</span>
      </div>
      <p>Last backup: Jun 04, 2026 at 09:41 AM</p>
    </div>
  );
}
