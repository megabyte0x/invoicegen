use crate::domain::{now_iso, InvoiceBook, CURRENT_SCHEMA_VERSION};
use crate::json;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug)]
pub struct LocalInvoiceStore {
    pub path: PathBuf,
}

impl LocalInvoiceStore {
    pub fn new(path: Option<PathBuf>) -> Self {
        Self {
            path: path.unwrap_or_else(default_store_path),
        }
    }

    pub fn load(&self) -> Result<InvoiceBook, String> {
        if !self.path.exists() {
            return Ok(InvoiceBook::empty());
        }
        let data = fs::read_to_string(&self.path)
            .map_err(|error| format!("failed to read {}: {error}", self.path.display()))?;
        let json = json::parse(&data)?;
        let mut book = InvoiceBook::from_json(&json)?;
        book.schema_version = CURRENT_SCHEMA_VERSION;
        book.refresh_invoice_statuses(&now_iso());
        Ok(book)
    }

    pub fn save(&self, book: &InvoiceBook) -> Result<(), String> {
        book.validate_for_save()?;

        let directory = self
            .path
            .parent()
            .ok_or_else(|| format!("store path has no parent: {}", self.path.display()))?;
        fs::create_dir_all(directory)
            .map_err(|error| format!("failed to create {}: {error}", directory.display()))?;

        if self.path.exists() {
            let backup = backup_path(&self.path);
            if backup.exists() {
                fs::remove_file(&backup)
                    .map_err(|error| format!("failed to remove {}: {error}", backup.display()))?;
            }
            fs::copy(&self.path, &backup).map_err(|error| {
                format!(
                    "failed to back up {} to {}: {error}",
                    self.path.display(),
                    backup.display()
                )
            })?;
        }

        let temp_path = self.path.with_extension("tmp");
        let data = json::stringify_pretty(&book.to_json());
        fs::write(&temp_path, data)
            .map_err(|error| format!("failed to write {}: {error}", temp_path.display()))?;
        replace_file(&temp_path, &self.path).map_err(|error| {
            format!(
                "failed to replace {} with {}: {error}",
                self.path.display(),
                temp_path.display()
            )
        })?;
        Ok(())
    }

    pub fn export_to(&self, destination: &Path) -> Result<(), String> {
        let _ = self.load()?;
        if self.path == destination {
            return Ok(());
        }

        if let Some(directory) = destination.parent() {
            fs::create_dir_all(directory)
                .map_err(|error| format!("failed to create {}: {error}", directory.display()))?;
        }
        if self.path.exists() {
            fs::copy(&self.path, destination).map_err(|error| {
                format!(
                    "failed to export {} to {}: {error}",
                    self.path.display(),
                    destination.display()
                )
            })?;
        } else {
            fs::write(
                destination,
                json::stringify_pretty(&InvoiceBook::empty().to_json()),
            )
            .map_err(|error| format!("failed to write {}: {error}", destination.display()))?;
        }
        Ok(())
    }

    pub fn restore_from(&self, source: &Path) -> Result<(), String> {
        let data = fs::read_to_string(source)
            .map_err(|error| format!("failed to read {}: {error}", source.display()))?;
        let json = json::parse(&data)?;
        let mut book = InvoiceBook::from_json(&json)?;
        book.schema_version = CURRENT_SCHEMA_VERSION;
        book.refresh_invoice_statuses(&now_iso());
        self.save(&book)
    }
}

pub fn backup_path(path: &Path) -> PathBuf {
    let file_name = path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| "store.json".to_string());
    path.with_file_name(format!("{file_name}.bak"))
}

fn default_store_path() -> PathBuf {
    let environment: Vec<(String, String)> = env::vars().collect();
    let environment_refs: Vec<(&str, &str)> = environment
        .iter()
        .map(|(key, value)| (key.as_str(), value.as_str()))
        .collect();
    default_store_path_for_environment(std::env::consts::OS, &environment_refs)
}

pub fn default_store_path_for_environment(platform: &str, environment: &[(&str, &str)]) -> PathBuf {
    if let Some(override_path) = env_value(environment, "INVOICEGEN_APP_STORE") {
        if !override_path.is_empty() {
            return expand_tilde(override_path, environment);
        }
    }

    match platform {
        "macos" => {
            if let Some(home) = env_value(environment, "HOME") {
                return PathBuf::from(home)
                    .join("Library")
                    .join("Application Support")
                    .join("InvoiceGen")
                    .join("store.json");
            }
        }
        "windows" => {
            if let Some(app_data) = env_value(environment, "APPDATA")
                .or_else(|| env_value(environment, "LOCALAPPDATA"))
                .or_else(|| env_value(environment, "USERPROFILE"))
                .or_else(|| env_value(environment, "HOME"))
            {
                return PathBuf::from(app_data)
                    .join("InvoiceGen")
                    .join("store.json");
            }
        }
        _ => {}
    }

    if let Some(xdg_data_home) = env_value(environment, "XDG_DATA_HOME") {
        if !xdg_data_home.is_empty() {
            return expand_tilde(xdg_data_home, environment)
                .join("invoicegen-app")
                .join("store.json");
        }
    }

    env_value(environment, "HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".local")
        .join("share")
        .join("invoicegen-app")
        .join("store.json")
}

fn env_value<'a>(environment: &'a [(&str, &str)], key: &str) -> Option<&'a str> {
    environment
        .iter()
        .find_map(|(candidate, value)| (*candidate == key).then_some(*value))
}

fn expand_tilde(value: &str, environment: &[(&str, &str)]) -> PathBuf {
    if value == "~" {
        return env_value(environment, "HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(value));
    }
    if let Some(rest) = value.strip_prefix("~/") {
        if let Some(home) = env_value(environment, "HOME") {
            return PathBuf::from(home).join(rest);
        }
    }
    PathBuf::from(value)
}

#[cfg(windows)]
fn replace_file(temp_path: &Path, destination: &Path) -> std::io::Result<()> {
    if destination.exists() {
        fs::remove_file(destination)?;
    }
    fs::rename(temp_path, destination)
}

#[cfg(not(windows))]
fn replace_file(temp_path: &Path, destination: &Path) -> std::io::Result<()> {
    fs::rename(temp_path, destination)
}
