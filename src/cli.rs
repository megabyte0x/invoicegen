use crate::domain::{
    add_days_iso, format_money, invoice_pdf_file_name, normalize_date_input, now_iso,
    parse_minor_units, render_invoice_pdf, render_invoice_text, BusinessProfile, Client, Invoice,
    InvoiceBook, InvoiceLineItem, InvoiceStatus, Payment, PaymentAcceptanceDetail,
    PaymentAcceptanceKind, Project,
};
use crate::json::{self, JsonValue};
use crate::store::LocalInvoiceStore;
use clap::{Arg, ArgAction, Command};
use clap_complete::{generate, Shell};
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

pub fn run_cli(args: impl IntoIterator<Item = String>) -> Result<String, String> {
    let mut args: Vec<String> = args.into_iter().collect();
    if let Some(help) = validate_with_clap(&args)? {
        return Ok(help);
    }
    let store_path = take_global_store_path(&mut args)?;
    let config_path = take_global_config_path(&mut args)?;
    let global_format = take_output_format(&mut args)?;
    let config = CliConfig::load(config_path.as_deref())?;
    let context = CliContext {
        config_path: config_path.unwrap_or_else(default_config_path),
        config,
        global_format,
    };

    if args.is_empty() {
        return Ok(global_help());
    }

    let command = args.remove(0);
    if command == "completion" {
        return command_completion(args);
    }
    let store = LocalInvoiceStore::new(store_path.or_else(|| context.config.store_path.clone()));
    match command.as_str() {
        "config" => command_config(&context, args),
        "store" => command_store(&context, store, args),
        "seed-sample" => command_seed_sample(store, args),
        "summary" => command_summary(&context, store, args),
        "profile" => command_profile(&context, store, args),
        "client" => command_client(&context, store, args),
        "project" => command_project(&context, store, args),
        "payment-detail" => command_payment_detail(&context, store, args),
        "invoice" => command_invoice(&context, store, args),
        _ => Err(cli_error(
            "unknown_command",
            format!("unknown command: {command}"),
            Some("run invoicegen-rs --help".to_string()),
        )),
    }
    .map_err(structure_unstructured_error)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum OutputFormat {
    Text,
    Tsv,
    Csv,
    Json,
}

impl OutputFormat {
    fn parse(value: &str) -> Result<Self, String> {
        match value {
            "text" | "plain" => Ok(Self::Text),
            "tsv" => Ok(Self::Tsv),
            "csv" => Ok(Self::Csv),
            "json" => Ok(Self::Json),
            _ => Err(cli_error(
                "invalid_output_format",
                format!("unsupported output format: {value}"),
                Some("use one of: text, tsv, csv, json".to_string()),
            )),
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Text => "text",
            Self::Tsv => "tsv",
            Self::Csv => "csv",
            Self::Json => "json",
        }
    }
}

#[derive(Clone, Debug, Default)]
struct CliConfig {
    store_path: Option<PathBuf>,
    default_output: Option<OutputFormat>,
}

#[derive(Clone, Debug)]
struct CliContext {
    config_path: PathBuf,
    config: CliConfig,
    global_format: Option<OutputFormat>,
}

fn command_config(context: &CliContext, mut args: Vec<String>) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "config command")?;
    match subcommand.as_str() {
        "path" => {
            reject_unknown(args)?;
            Ok(format!("{}\n", context.config_path.display()))
        }
        "show" => {
            let format = output_format_for(&mut args, context)?;
            reject_unknown(args)?;
            format_config(&context.config, &context.config_path, format)
        }
        "set" => {
            let mut config = context.config.clone();
            if let Some(store_path) = take_option(&mut args, "--store") {
                config.store_path = Some(PathBuf::from(store_path));
            }
            if let Some(default_output) = take_option(&mut args, "--default-output")
                .or_else(|| take_option(&mut args, "--output"))
            {
                config.default_output = Some(OutputFormat::parse(&default_output)?);
            }
            reject_unknown(args)?;
            config.save(&context.config_path)?;
            Ok(format!(
                "Updated config at {}\n",
                context.config_path.display()
            ))
        }
        _ => Err(cli_error(
            "unknown_command",
            format!("unknown config command: {subcommand}"),
            Some("run invoicegen-rs config --help".to_string()),
        )),
    }
}

fn command_store(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = args.first().map(String::as_str).unwrap_or("path");
    match subcommand {
        "path" => {
            if !args.is_empty() {
                args.remove(0);
            }
            let format = output_format_for(&mut args, context)?;
            reject_unknown(args)?;
            match format {
                OutputFormat::Json => Ok(json_string(json::object([(
                    "path".to_string(),
                    json::string(store.path.display().to_string()),
                )]))),
                _ => Ok(format!("{}\n", store.path.display())),
            }
        }
        "export" => {
            args.remove(0);
            let destination = PathBuf::from(next_arg(&mut args, "export path")?);
            reject_unknown(args)?;
            store.export_to(&destination)?;
            Ok(format!("Exported store to {}\n", destination.display()))
        }
        "restore" => {
            args.remove(0);
            let source = PathBuf::from(next_arg(&mut args, "backup path")?);
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            store.restore_from(&source)?;
            Ok(format!("Restored store from {}\n", source.display()))
        }
        _ => Err(cli_error(
            "unknown_command",
            format!("unknown store command: {subcommand}"),
            Some("run invoicegen-rs store --help".to_string()),
        )),
    }
}

fn command_seed_sample(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let force = take_flag(&mut args, "--force");
    reject_unknown(args)?;
    if store.path.exists() && !force {
        return Err(cli_error(
            "destructive_action_requires_force",
            format!("store already exists: {}", store.path.display()),
            Some("pass --force to replace it".to_string()),
        ));
    }
    let now = now_iso();
    let book = InvoiceBook::sample(&now);
    store.save(&book)?;
    Ok(format!("Seeded sample data at {}\n", store.path.display()))
}

fn command_summary(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let format = output_format_for(&mut args, context)?;
    reject_unknown(args)?;
    let book = store.load()?;
    let outstanding: i64 = book
        .invoices
        .iter()
        .map(Invoice::balance_due_minor_units)
        .sum();
    let paid: i64 = book.invoices.iter().map(Invoice::paid_minor_units).sum();
    let overdue = book
        .invoices
        .iter()
        .filter(|invoice| invoice.status == InvoiceStatus::Overdue)
        .count();
    match format {
        OutputFormat::Json => Ok(json_string(json::object([
            (
                "outstanding".to_string(),
                json::string(format_money(
                    outstanding,
                    &book.business_profile.currency_code,
                )),
            ),
            (
                "paidToDate".to_string(),
                json::string(format_money(paid, &book.business_profile.currency_code)),
            ),
            ("totalClients".to_string(), json::number(book.clients.len())),
            ("overdueInvoices".to_string(), json::number(overdue)),
            (
                "store".to_string(),
                json::string(store.path.display().to_string()),
            ),
        ]))),
        OutputFormat::Csv => Ok(csv_rows(
            &["metric", "value"],
            &[
                vec![
                    "outstanding".to_string(),
                    format_money(outstanding, &book.business_profile.currency_code),
                ],
                vec![
                    "paidToDate".to_string(),
                    format_money(paid, &book.business_profile.currency_code),
                ],
                vec!["totalClients".to_string(), book.clients.len().to_string()],
                vec!["overdueInvoices".to_string(), overdue.to_string()],
                vec!["store".to_string(), store.path.display().to_string()],
            ],
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["metric", "value"],
            &[
                vec![
                    "outstanding".to_string(),
                    format_money(outstanding, &book.business_profile.currency_code),
                ],
                vec![
                    "paidToDate".to_string(),
                    format_money(paid, &book.business_profile.currency_code),
                ],
                vec!["totalClients".to_string(), book.clients.len().to_string()],
                vec!["overdueInvoices".to_string(), overdue.to_string()],
                vec!["store".to_string(), store.path.display().to_string()],
            ],
        )),
        OutputFormat::Text => Ok(format!(
            "Outstanding: {}\nPaid to Date: {}\nTotal Clients: {}\nOverdue Invoices: {}\nStore: {}\n",
            format_money(outstanding, &book.business_profile.currency_code),
            format_money(paid, &book.business_profile.currency_code),
            book.clients.len(),
            overdue,
            store.path.display()
        )),
    }
}

fn command_profile(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "profile command")?;
    match subcommand.as_str() {
        "show" => {
            let format = output_format_for(&mut args, context)?;
            reject_unknown(args)?;
            let book = store.load()?;
            format_profile(&book.business_profile, format)
        }
        "set" => {
            let mut book = store.load()?;
            if let Some(name) = take_option(&mut args, "--name") {
                book.business_profile.name = name;
            }
            if let Some(email) = take_option(&mut args, "--email") {
                book.business_profile.email = email;
            }
            if let Some(address) = take_option(&mut args, "--address") {
                book.business_profile.address = address;
            }
            if let Some(tax_id) = take_option(&mut args, "--tax-id") {
                book.business_profile.tax_identifier = tax_id;
            }
            if let Some(currency) = take_option(&mut args, "--currency") {
                book.business_profile.currency_code = currency;
            }
            if let Some(days) = take_option(&mut args, "--terms-days") {
                let parsed = parse_i64(&days, "--terms-days")?;
                book.business_profile.payment_terms_days = parsed.clamp(0, 120);
            }
            reject_unknown(args)?;
            store.save(&book)?;
            Ok("Updated profile\n".to_string())
        }
        _ => Err(format!("unknown profile command: {subcommand}")),
    }
}

fn command_client(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "client command")?;
    match subcommand.as_str() {
        "list" => {
            let format = output_format_for(&mut args, context)?;
            let query = take_option(&mut args, "--query").map(|value| value.to_lowercase());
            let sort = take_option(&mut args, "--sort").unwrap_or_else(|| "name".to_string());
            let reverse = take_flag(&mut args, "--reverse");
            reject_unknown(args)?;
            let mut clients = store.load()?.clients;
            if let Some(query) = query {
                clients.retain(|client| {
                    contains_ci(&client.id, &query)
                        || contains_ci(&client.name, &query)
                        || contains_ci(&client.email, &query)
                        || contains_ci(&client.company, &query)
                });
            }
            clients.sort_by(|left, right| match sort.as_str() {
                "id" => left.id.cmp(&right.id),
                "email" => left.email.to_lowercase().cmp(&right.email.to_lowercase()),
                "company" => left
                    .company
                    .to_lowercase()
                    .cmp(&right.company.to_lowercase()),
                _ => left.name.to_lowercase().cmp(&right.name.to_lowercase()),
            });
            if reverse {
                clients.reverse();
            }
            format_clients(&clients, format)
        }
        "add" => {
            let now = now_iso();
            let mut book = store.load()?;
            let mut client = Client::new(
                take_option(&mut args, "--name").unwrap_or_else(|| "New Client".to_string()),
                &now,
            );
            apply_client_options(&mut client, &mut args)?;
            reject_unknown(args)?;
            let id = client.id.clone();
            book.clients.insert(0, client);
            store.save(&book)?;
            Ok(format!("Created client {id}\n"))
        }
        "update" => {
            let id = next_arg(&mut args, "client id")?;
            let mut book = store.load()?;
            let index = find_client_index(&book, &id)?;
            apply_client_options(&mut book.clients[index], &mut args)?;
            book.clients[index].updated_at = now_iso();
            reject_unknown(args)?;
            store.save(&book)?;
            Ok(format!("Updated client {id}\n"))
        }
        "delete" => {
            let id = next_arg(&mut args, "client id")?;
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            let mut book = store.load()?;
            find_client_index(&book, &id)?;
            book.clients.retain(|client| client.id != id);
            for invoice in &mut book.invoices {
                if invoice.client_id.as_deref() == Some(&id) {
                    invoice.client_id = None;
                }
            }
            for project in &mut book.projects {
                if project.client_id.as_deref() == Some(&id) {
                    project.client_id = None;
                }
            }
            store.save(&book)?;
            Ok(format!("Deleted client {id}\n"))
        }
        _ => Err(format!("unknown client command: {subcommand}")),
    }
}

fn command_project(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "project command")?;
    match subcommand.as_str() {
        "list" => {
            let format = output_format_for(&mut args, context)?;
            let query = take_option(&mut args, "--query").map(|value| value.to_lowercase());
            let client_filter =
                take_option(&mut args, "--client").map(|value| parse_optional_id(&value));
            let sort = take_option(&mut args, "--sort").unwrap_or_else(|| "name".to_string());
            let reverse = take_flag(&mut args, "--reverse");
            reject_unknown(args)?;
            let book = store.load()?;
            let mut projects = book.projects.clone();
            if let Some(query) = query {
                projects.retain(|project| {
                    let client_name = project
                        .client_id
                        .as_ref()
                        .and_then(|id| book.clients.iter().find(|client| &client.id == id))
                        .map(|client| client.name.as_str())
                        .unwrap_or("");
                    contains_ci(&project.id, &query)
                        || contains_ci(&project.name, &query)
                        || contains_ci(&project.summary, &query)
                        || contains_ci(client_name, &query)
                });
            }
            if let Some(client_filter) = client_filter {
                projects.retain(|project| project.client_id == client_filter);
            }
            projects.sort_by(|left, right| match sort.as_str() {
                "id" => left.id.cmp(&right.id),
                "rate" => left
                    .hourly_rate_minor_units
                    .cmp(&right.hourly_rate_minor_units),
                _ => left.name.to_lowercase().cmp(&right.name.to_lowercase()),
            });
            if reverse {
                projects.reverse();
            }
            format_projects(&projects, &book, format)
        }
        "add" => {
            let now = now_iso();
            let mut book = store.load()?;
            let mut project = Project::new(
                take_option(&mut args, "--name").unwrap_or_else(|| "New Project".to_string()),
                book.business_profile.currency_code.clone(),
                &now,
            );
            apply_project_options(&book, &mut project, &mut args)?;
            reject_unknown(args)?;
            let id = project.id.clone();
            book.projects.insert(0, project);
            store.save(&book)?;
            Ok(format!("Created project {id}\n"))
        }
        "update" => {
            let id = next_arg(&mut args, "project id")?;
            let mut book = store.load()?;
            let index = find_project_index(&book, &id)?;
            let mut project = book.projects[index].clone();
            apply_project_options(&book, &mut project, &mut args)?;
            project.updated_at = now_iso();
            reject_unknown(args)?;
            book.projects[index] = project;
            store.save(&book)?;
            Ok(format!("Updated project {id}\n"))
        }
        "delete" => {
            let id = next_arg(&mut args, "project id")?;
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            let mut book = store.load()?;
            find_project_index(&book, &id)?;
            book.projects.retain(|project| project.id != id);
            for invoice in &mut book.invoices {
                if invoice.project_id.as_deref() == Some(&id) {
                    invoice.project_id = None;
                }
            }
            store.save(&book)?;
            Ok(format!("Deleted project {id}\n"))
        }
        _ => Err(format!("unknown project command: {subcommand}")),
    }
}

fn command_payment_detail(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "payment-detail command")?;
    match subcommand.as_str() {
        "list" => {
            let format = output_format_for(&mut args, context)?;
            let query = take_option(&mut args, "--query").map(|value| value.to_lowercase());
            reject_unknown(args)?;
            let book = store.load()?;
            let mut details = book.payment_acceptance_details;
            if let Some(query) = query {
                details.retain(|detail| {
                    contains_ci(&detail.id, &query)
                        || contains_ci(detail.kind.raw_value(), &query)
                        || contains_ci(&detail.label, &query)
                        || contains_ci(&detail.details, &query)
                });
            }
            format_payment_details(&details, format)
        }
        "add" => {
            let now = now_iso();
            let mut book = store.load()?;
            let kind = take_option(&mut args, "--kind")
                .map(|value| PaymentAcceptanceKind::parse(&value))
                .transpose()?
                .unwrap_or(PaymentAcceptanceKind::BankDetails);
            let mut detail = PaymentAcceptanceDetail::new(kind, &now);
            apply_payment_detail_options(&mut detail, &mut args)?;
            reject_unknown(args)?;
            let id = detail.id.clone();
            book.payment_acceptance_details.push(detail);
            store.save(&book)?;
            Ok(format!("Created payment detail {id}\n"))
        }
        "update" => {
            let id = next_arg(&mut args, "payment detail id")?;
            let mut book = store.load()?;
            let index = find_payment_detail_index(&book, &id)?;
            apply_payment_detail_options(&mut book.payment_acceptance_details[index], &mut args)?;
            book.payment_acceptance_details[index].updated_at = now_iso();
            reject_unknown(args)?;
            store.save(&book)?;
            Ok(format!("Updated payment detail {id}\n"))
        }
        "delete" => {
            let id = next_arg(&mut args, "payment detail id")?;
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            let mut book = store.load()?;
            find_payment_detail_index(&book, &id)?;
            book.payment_acceptance_details
                .retain(|detail| detail.id != id);
            for invoice in &mut book.invoices {
                invoice
                    .accepted_payment_detail_ids
                    .retain(|detail_id| detail_id != &id);
            }
            store.save(&book)?;
            Ok(format!("Deleted payment detail {id}\n"))
        }
        _ => Err(format!("unknown payment-detail command: {subcommand}")),
    }
}

fn command_invoice(
    context: &CliContext,
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "invoice command")?;
    match subcommand.as_str() {
        "list" => {
            let format = output_format_for(&mut args, context)?;
            let status_filter = take_option(&mut args, "--status")
                .map(|value| InvoiceStatus::parse(&value))
                .transpose()?;
            let client_filter =
                take_option(&mut args, "--client").map(|value| parse_optional_id(&value));
            let query = take_option(&mut args, "--query").map(|value| value.to_lowercase());
            let sort = take_option(&mut args, "--sort").unwrap_or_else(|| "issue-date".to_string());
            let reverse = take_flag(&mut args, "--reverse");
            reject_unknown(args)?;
            let book = store.load()?;
            let mut invoices = book.invoices.clone();
            if let Some(status) = status_filter {
                invoices.retain(|invoice| invoice.status == status);
            }
            if let Some(client_filter) = client_filter {
                invoices.retain(|invoice| invoice.client_id == client_filter);
            }
            if let Some(query) = query {
                invoices.retain(|invoice| {
                    let client = book
                        .client_for(invoice)
                        .map(|client| client.name.as_str())
                        .unwrap_or("");
                    contains_ci(&invoice.id, &query)
                        || contains_ci(&invoice.number, &query)
                        || contains_ci(client, &query)
                        || contains_ci(invoice.status.raw_value(), &query)
                });
            }
            invoices.sort_by(|left, right| match sort.as_str() {
                "id" => left.id.cmp(&right.id),
                "number" => left.number.cmp(&right.number),
                "due-date" | "due" => left.due_date.cmp(&right.due_date),
                "balance" => left
                    .balance_due_minor_units()
                    .cmp(&right.balance_due_minor_units()),
                "status" => left.status.raw_value().cmp(right.status.raw_value()),
                _ => left.issue_date.cmp(&right.issue_date),
            });
            if !reverse {
                invoices.reverse();
            }
            format_invoices(&invoices, &book, format)
        }
        "add" => {
            let now = now_iso();
            let mut book = store.load()?;
            let issue_date = take_option(&mut args, "--issue-date")
                .map(|value| normalize_date_input(&value))
                .transpose()?
                .unwrap_or_else(|| now.clone());
            let due_date = take_option(&mut args, "--due-date")
                .map(|value| normalize_date_input(&value))
                .transpose()?
                .unwrap_or_else(|| {
                    add_days_iso(&issue_date, book.business_profile.payment_terms_days)
                });
            let number = take_option(&mut args, "--number")
                .unwrap_or_else(|| book.next_invoice_number(&issue_date));
            let mut invoice = Invoice::new(number, due_date, &now);
            invoice.issue_date = issue_date;
            invoice.currency_code = take_option(&mut args, "--currency")
                .unwrap_or_else(|| book.business_profile.currency_code.clone());
            invoice.client_id =
                take_optional_existing_id(&book, &mut args, "--client", EntityKind::Client)?;
            if invoice.client_id.is_none() {
                invoice.client_id = book.clients.first().map(|client| client.id.clone());
            }
            invoice.project_id =
                take_optional_existing_id(&book, &mut args, "--project", EntityKind::Project)?;
            if let Some(notes) = take_option(&mut args, "--notes") {
                invoice.notes = notes;
            }
            invoice.terms = take_option(&mut args, "--terms")
                .unwrap_or_else(|| format!("Net {}.", book.business_profile.payment_terms_days));
            if let Some(status) = take_option(&mut args, "--status") {
                invoice.status = InvoiceStatus::parse(&status)?;
            }
            if !take_flag(&mut args, "--no-default-item") {
                invoice
                    .line_items
                    .push(InvoiceLineItem::new("Professional services".to_string(), 0));
            }
            reject_unknown(args)?;
            let id = invoice.id.clone();
            book.invoices.insert(0, invoice);
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Created invoice {id}\n"))
        }
        "update" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            let mut invoice = book.invoices[index].clone();
            apply_invoice_options(&book, &mut invoice, &mut args)?;
            invoice.updated_at = now_iso();
            reject_unknown(args)?;
            book.invoices[index] = invoice;
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Updated invoice {id}\n"))
        }
        "delete" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            let removed_id = book.invoices[index].id.clone();
            book.invoices.remove(index);
            store.save(&book)?;
            Ok(format!("Deleted invoice {removed_id}\n"))
        }
        "add-item" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            let mut item = InvoiceLineItem::new(
                take_option(&mut args, "--title").unwrap_or_else(|| "New Item".to_string()),
                take_option(&mut args, "--unit-price")
                    .map(|value| parse_minor_units(&value))
                    .transpose()?
                    .unwrap_or(0),
            );
            apply_line_item_options(&mut item, &mut args)?;
            reject_unknown(args)?;
            let item_id = item.id.clone();
            book.invoices[index].line_items.push(item);
            book.invoices[index].updated_at = now_iso();
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Created line item {item_id}\n"))
        }
        "update-item" => {
            let invoice_id = next_arg(&mut args, "invoice id or number")?;
            let item_id = next_arg(&mut args, "line item id")?;
            let mut book = store.load()?;
            let invoice_index = find_invoice_index(&book, &invoice_id)?;
            let item_index = find_line_item_index(&book.invoices[invoice_index], &item_id)?;
            apply_line_item_options(
                &mut book.invoices[invoice_index].line_items[item_index],
                &mut args,
            )?;
            book.invoices[invoice_index].updated_at = now_iso();
            reject_unknown(args)?;
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Updated line item {item_id}\n"))
        }
        "delete-item" => {
            let invoice_id = next_arg(&mut args, "invoice id or number")?;
            let item_id = next_arg(&mut args, "line item id")?;
            let force = take_flag(&mut args, "--force");
            reject_unknown(args)?;
            require_force(force)?;
            let mut book = store.load()?;
            let invoice_index = find_invoice_index(&book, &invoice_id)?;
            find_line_item_index(&book.invoices[invoice_index], &item_id)?;
            book.invoices[invoice_index]
                .line_items
                .retain(|item| item.id != item_id);
            book.invoices[invoice_index].updated_at = now_iso();
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Deleted line item {item_id}\n"))
        }
        "mark-sent" => set_invoice_status(&store, args, InvoiceStatus::Sent, "Marked invoice sent"),
        "set-status" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let status = InvoiceStatus::parse(&next_arg(&mut args, "status")?)?;
            reject_unknown(args)?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            book.invoices[index].status = status;
            book.invoices[index].updated_at = now_iso();
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Updated invoice {id}\n"))
        }
        "mark-paid" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            let amount = take_option(&mut args, "--amount")
                .map(|value| parse_minor_units(&value))
                .transpose()?
                .unwrap_or_else(|| book.invoices[index].balance_due_minor_units());
            let now = now_iso();
            let mut payment = Payment::new(amount, &now);
            if let Some(reference) = take_option(&mut args, "--reference") {
                payment.reference = reference;
            }
            if let Some(notes) = take_option(&mut args, "--notes") {
                payment.notes = notes;
            }
            reject_unknown(args)?;
            book.invoices[index].payments.push(payment);
            book.invoices[index].refresh_status(&now);
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Marked invoice {id} paid\n"))
        }
        "mark-unpaid" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            reject_unknown(args)?;
            let mut book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            book.invoices[index].mark_unpaid(&now_iso());
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!("Marked invoice {id} unpaid\n"))
        }
        "accept-payment" => {
            let invoice_id = next_arg(&mut args, "invoice id or number")?;
            let payment_detail_id = next_arg(&mut args, "payment detail id")?;
            reject_unknown(args)?;
            let mut book = store.load()?;
            find_payment_detail_index(&book, &payment_detail_id)?;
            let invoice_index = find_invoice_index(&book, &invoice_id)?;
            if !book.invoices[invoice_index]
                .accepted_payment_detail_ids
                .contains(&payment_detail_id)
            {
                book.invoices[invoice_index]
                    .accepted_payment_detail_ids
                    .push(payment_detail_id.clone());
            }
            book.invoices[invoice_index].updated_at = now_iso();
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!(
                "Attached payment detail {payment_detail_id} to invoice {invoice_id}\n"
            ))
        }
        "detach-payment" => {
            let invoice_id = next_arg(&mut args, "invoice id or number")?;
            let payment_detail_id = next_arg(&mut args, "payment detail id")?;
            reject_unknown(args)?;
            let mut book = store.load()?;
            let invoice_index = find_invoice_index(&book, &invoice_id)?;
            book.invoices[invoice_index]
                .accepted_payment_detail_ids
                .retain(|id| id != &payment_detail_id);
            book.invoices[invoice_index].updated_at = now_iso();
            save_book_with_refresh(&store, &mut book)?;
            Ok(format!(
                "Detached payment detail {payment_detail_id} from invoice {invoice_id}\n"
            ))
        }
        "render" => {
            let id = next_arg(&mut args, "invoice id or number")?;
            let output_path = take_option(&mut args, "--output").map(PathBuf::from);
            reject_unknown(args)?;
            let book = store.load()?;
            let index = find_invoice_index(&book, &id)?;
            if let Some(output_path) = output_path {
                let output_path = invoice_render_output_path(output_path, &book.invoices[index]);
                let pdf = render_invoice_pdf(&book.invoices[index], &book);
                fs::write(&output_path, pdf).map_err(|error| {
                    format!("failed to write {}: {error}", output_path.display())
                })?;
                Ok(format!("Wrote {}\n", output_path.display()))
            } else {
                let rendered = render_invoice_text(&book.invoices[index], &book);
                Ok(format!("{rendered}\n"))
            }
        }
        _ => Err(format!("unknown invoice command: {subcommand}")),
    }
}

fn set_invoice_status(
    store: &LocalInvoiceStore,
    mut args: Vec<String>,
    status: InvoiceStatus,
    message: &str,
) -> Result<String, String> {
    let id = next_arg(&mut args, "invoice id or number")?;
    reject_unknown(args)?;
    let mut book = store.load()?;
    let index = find_invoice_index(&book, &id)?;
    book.invoices[index].status = status;
    book.invoices[index].updated_at = now_iso();
    save_book_with_refresh(store, &mut book)?;
    Ok(format!("{message} {id}\n"))
}

fn save_book_with_refresh(store: &LocalInvoiceStore, book: &mut InvoiceBook) -> Result<(), String> {
    book.refresh_invoice_statuses(&now_iso());
    store.save(book)
}

fn apply_client_options(client: &mut Client, args: &mut Vec<String>) -> Result<(), String> {
    if let Some(name) = take_option(args, "--name") {
        client.name = name;
    }
    if let Some(company) = take_option(args, "--company") {
        client.company = company;
    }
    if let Some(email) = take_option(args, "--email") {
        client.email = email;
    }
    if let Some(address) = take_option(args, "--address") {
        client.address = address;
    }
    if let Some(notes) = take_option(args, "--notes") {
        client.notes = notes;
    }
    Ok(())
}

fn apply_project_options(
    book: &InvoiceBook,
    project: &mut Project,
    args: &mut Vec<String>,
) -> Result<(), String> {
    if let Some(name) = take_option(args, "--name") {
        project.name = name;
    }
    if let Some(summary) = take_option(args, "--summary") {
        project.summary = summary;
    }
    if let Some(currency) = take_option(args, "--currency") {
        project.currency_code = currency;
    }
    if let Some(rate) = take_option(args, "--rate") {
        project.hourly_rate_minor_units = parse_minor_units(&rate)?;
    }
    if let Some(client_id) = take_option(args, "--client") {
        project.client_id = parse_optional_id(&client_id);
        if let Some(client_id) = &project.client_id {
            find_client_index(book, client_id)?;
        }
    }
    Ok(())
}

fn apply_payment_detail_options(
    detail: &mut PaymentAcceptanceDetail,
    args: &mut Vec<String>,
) -> Result<(), String> {
    if let Some(kind) = take_option(args, "--kind") {
        detail.kind = PaymentAcceptanceKind::parse(&kind)?;
    }
    if let Some(label) = take_option(args, "--label") {
        detail.label = label;
    }
    if let Some(details) = take_option(args, "--details") {
        detail.details = details;
    }
    let detail_lines = take_all_options(args, "--detail");
    if !detail_lines.is_empty() {
        detail.details = detail_lines.join("\n");
    }
    Ok(())
}

fn apply_invoice_options(
    book: &InvoiceBook,
    invoice: &mut Invoice,
    args: &mut Vec<String>,
) -> Result<(), String> {
    if let Some(number) = take_option(args, "--number") {
        invoice.number = number;
    }
    if let Some(client_id) = take_option(args, "--client") {
        invoice.client_id = parse_optional_id(&client_id);
        if let Some(client_id) = &invoice.client_id {
            find_client_index(book, client_id)?;
        }
    }
    if let Some(project_id) = take_option(args, "--project") {
        invoice.project_id = parse_optional_id(&project_id);
        if let Some(project_id) = &invoice.project_id {
            find_project_index(book, project_id)?;
        }
    }
    if let Some(issue_date) = take_option(args, "--issue-date") {
        invoice.issue_date = normalize_date_input(&issue_date)?;
    }
    if let Some(due_date) = take_option(args, "--due-date") {
        invoice.due_date = normalize_date_input(&due_date)?;
    }
    if let Some(status) = take_option(args, "--status") {
        invoice.status = InvoiceStatus::parse(&status)?;
    }
    if let Some(currency) = take_option(args, "--currency") {
        invoice.currency_code = currency;
    }
    if let Some(notes) = take_option(args, "--notes") {
        invoice.notes = notes;
    }
    if let Some(terms) = take_option(args, "--terms") {
        invoice.terms = terms;
    }
    Ok(())
}

fn apply_line_item_options(
    item: &mut InvoiceLineItem,
    args: &mut Vec<String>,
) -> Result<(), String> {
    if let Some(title) = take_option(args, "--title") {
        item.title = title;
    }
    if let Some(details) = take_option(args, "--details") {
        item.details = details;
    }
    if let Some(quantity) = take_option(args, "--quantity") {
        item.quantity = parse_f64(&quantity, "--quantity")?;
    }
    if let Some(unit_price) = take_option(args, "--unit-price") {
        item.unit_price_minor_units = parse_minor_units(&unit_price)?;
    }
    if let Some(tax_rate) = take_option(args, "--tax-rate") {
        item.tax_rate_percent = parse_f64(&tax_rate, "--tax-rate")?;
    }
    Ok(())
}

#[derive(Clone, Copy)]
enum EntityKind {
    Client,
    Project,
}

fn take_optional_existing_id(
    book: &InvoiceBook,
    args: &mut Vec<String>,
    option: &str,
    kind: EntityKind,
) -> Result<Option<String>, String> {
    let Some(value) = take_option(args, option) else {
        return Ok(None);
    };
    let id = parse_optional_id(&value);
    if let Some(id) = &id {
        match kind {
            EntityKind::Client => {
                find_client_index(book, id)?;
            }
            EntityKind::Project => {
                find_project_index(book, id)?;
            }
        }
    }
    Ok(id)
}

fn parse_optional_id(value: &str) -> Option<String> {
    match value {
        "" | "none" | "null" | "unassigned" => None,
        _ => Some(value.to_string()),
    }
}

fn render_profile(profile: &BusinessProfile) -> String {
    format!(
        "Name: {}\nEmail: {}\nAddress: {}\nTax ID: {}\nCurrency: {}\nPayment Terms Days: {}\n",
        profile.name,
        profile.email,
        profile.address,
        profile.tax_identifier,
        profile.currency_code,
        profile.payment_terms_days
    )
}

fn find_client_index(book: &InvoiceBook, id: &str) -> Result<usize, String> {
    book.clients
        .iter()
        .position(|client| client.id == id)
        .ok_or_else(|| format!("client not found: {id}"))
}

fn find_project_index(book: &InvoiceBook, id: &str) -> Result<usize, String> {
    book.projects
        .iter()
        .position(|project| project.id == id)
        .ok_or_else(|| format!("project not found: {id}"))
}

fn find_payment_detail_index(book: &InvoiceBook, id: &str) -> Result<usize, String> {
    book.payment_acceptance_details
        .iter()
        .position(|detail| detail.id == id)
        .ok_or_else(|| format!("payment detail not found: {id}"))
}

fn find_invoice_index(book: &InvoiceBook, id_or_number: &str) -> Result<usize, String> {
    book.invoices
        .iter()
        .position(|invoice| invoice.id == id_or_number || invoice.number == id_or_number)
        .ok_or_else(|| format!("invoice not found: {id_or_number}"))
}

fn find_line_item_index(invoice: &Invoice, item_id: &str) -> Result<usize, String> {
    invoice
        .line_items
        .iter()
        .position(|item| item.id == item_id)
        .ok_or_else(|| format!("line item not found: {item_id}"))
}

impl CliConfig {
    fn load(path: Option<&Path>) -> Result<Self, String> {
        let path = path
            .map(Path::to_path_buf)
            .unwrap_or_else(default_config_path);
        if !path.exists() {
            return Ok(Self::default());
        }
        let data = fs::read_to_string(&path)
            .map_err(|error| format!("failed to read {}: {error}", path.display()))?;
        let json = json::parse(&data)?;
        let object = json
            .as_object()
            .ok_or_else(|| "config root must be a JSON object".to_string())?;
        let store_path = object
            .get("storePath")
            .and_then(JsonValue::as_str)
            .filter(|value| !value.is_empty())
            .map(PathBuf::from);
        let default_output = object
            .get("defaultOutput")
            .and_then(JsonValue::as_str)
            .map(OutputFormat::parse)
            .transpose()?;
        Ok(Self {
            store_path,
            default_output,
        })
    }

    fn save(&self, path: &Path) -> Result<(), String> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .map_err(|error| format!("failed to create {}: {error}", parent.display()))?;
        }
        let mut entries = BTreeMap::new();
        if let Some(store_path) = &self.store_path {
            entries.insert(
                "storePath".to_string(),
                json::string(store_path.display().to_string()),
            );
        }
        if let Some(default_output) = self.default_output {
            entries.insert(
                "defaultOutput".to_string(),
                json::string(default_output.as_str()),
            );
        }
        fs::write(path, json_string(JsonValue::Object(entries)))
            .map_err(|error| format!("failed to write {}: {error}", path.display()))
    }
}

fn validate_with_clap(args: &[String]) -> Result<Option<String>, String> {
    let mut command = build_command();
    let mut argv = vec!["invoicegen-rs".to_string()];
    argv.extend(args.iter().cloned());
    match command.try_get_matches_from_mut(argv) {
        Ok(_) => Ok(None),
        Err(error)
            if matches!(
                error.kind(),
                clap::error::ErrorKind::DisplayHelp | clap::error::ErrorKind::DisplayVersion
            ) =>
        {
            Ok(Some(error.to_string()))
        }
        Err(error) => Err(format_clap_error(error)),
    }
}

fn build_command() -> Command {
    Command::new("invoicegen-rs")
        .version(env!("CARGO_PKG_VERSION"))
        .about("Local-first invoice generation CLI for Local Invoice")
        .disable_colored_help(true)
        .arg(option("store", "store", "PATH"))
        .arg(option("config", "config", "PATH"))
        .arg(
            option("format", "format", "FORMAT")
                .global(true)
                .value_parser(["text", "plain", "tsv", "csv", "json"])
                .help("Output format for commands that support structured output"),
        )
        .after_help(
            "Examples:\n  invoicegen-rs --store /tmp/invoicegen-store.json seed-sample --force\n  invoicegen-rs --store /tmp/invoicegen-store.json invoice list --status overdue --format json\n  invoicegen-rs config set --store ~/invoices/store.json --default-output json",
        )
        .subcommand(Command::new("completion")
            .about("Generate shell completion scripts")
            .arg(Arg::new("shell").required(true).value_parser(["bash", "zsh", "fish"])))
        .subcommand(Command::new("config")
            .about("Inspect or update CLI defaults")
            .after_help("Examples:\n  invoicegen-rs config show --format json\n  invoicegen-rs config set --store ~/invoices/store.json --default-output json")
            .subcommand(Command::new("path"))
            .subcommand(Command::new("show"))
            .subcommand(Command::new("set")
                .arg(option("store", "store", "PATH"))
                .arg(option("default-output", "default-output", "FORMAT").value_parser(["text", "plain", "tsv", "csv", "json"]))
                .arg(option("output", "output", "FORMAT").value_parser(["text", "plain", "tsv", "csv", "json"]))))
        .subcommand(Command::new("store")
            .about("Inspect, export, or restore the local store")
            .after_help("Examples:\n  invoicegen-rs store path\n  invoicegen-rs store path --format json\n  invoicegen-rs store export ./store-backup.json\n  invoicegen-rs store restore ./store-backup.json --force")
            .subcommand(Command::new("path"))
            .subcommand(Command::new("export").arg(Arg::new("path").required(true)))
            .subcommand(Command::new("restore")
                .arg(Arg::new("path").required(true))
                .arg(force_arg())))
        .subcommand(Command::new("seed-sample")
            .about("Seed sample data")
            .arg(force_arg()))
        .subcommand(Command::new("summary")
            .about("Show invoice totals")
            .after_help("Examples:\n  invoicegen-rs summary\n  invoicegen-rs summary --format json"))
        .subcommand(profile_command())
        .subcommand(client_command())
        .subcommand(project_command())
        .subcommand(payment_detail_command())
        .subcommand(invoice_command())
}

fn profile_command() -> Command {
    Command::new("profile")
        .about("Manage the business profile")
        .after_help(
            "Examples:\n  invoicegen-rs profile show --format json\n  invoicegen-rs profile set --name \"Acme Studio\" --currency USD",
        )
        .subcommand(Command::new("show"))
        .subcommand(
            Command::new("set")
                .arg(option("name", "name", "TEXT"))
                .arg(option("email", "email", "TEXT"))
                .arg(option("address", "address", "TEXT"))
                .arg(option("tax-id", "tax-id", "TEXT"))
                .arg(option("currency", "currency", "CODE"))
                .arg(option("terms-days", "terms-days", "N")),
        )
}

fn client_command() -> Command {
    Command::new("client")
        .about("Manage clients")
        .after_help(
            "Examples:\n  invoicegen-rs client list --query acme --format csv\n  invoicegen-rs client add --name \"Acme Co\" --email billing@acme.example\n  invoicegen-rs client delete CLIENT_ID --force",
        )
        .subcommand(
            Command::new("list")
                .arg(option("query", "query", "TEXT"))
                .arg(option("sort", "sort", "FIELD"))
                .arg(reverse_arg()),
        )
        .subcommand(client_write_command("add", false))
        .subcommand(client_write_command("update", true))
        .subcommand(
            Command::new("delete")
                .arg(Arg::new("id").required(true))
                .arg(force_arg()),
        )
}

fn client_write_command(name: &'static str, needs_id: bool) -> Command {
    let mut command = Command::new(name)
        .arg(option("name", "name", "TEXT"))
        .arg(option("company", "company", "TEXT"))
        .arg(option("email", "email", "TEXT"))
        .arg(option("address", "address", "TEXT"))
        .arg(option("notes", "notes", "TEXT"));
    if needs_id {
        command = command.arg(Arg::new("id").required(true));
    }
    command
}

fn project_command() -> Command {
    Command::new("project")
        .about("Manage projects")
        .after_help(
            "Examples:\n  invoicegen-rs project list --client CLIENT_ID --format json\n  invoicegen-rs project add --name Launch --client CLIENT_ID --rate 125.00\n  invoicegen-rs project delete PROJECT_ID --force",
        )
        .subcommand(
            Command::new("list")
                .arg(option("query", "query", "TEXT"))
                .arg(option("client", "client", "ID|none"))
                .arg(option("sort", "sort", "FIELD"))
                .arg(reverse_arg()),
        )
        .subcommand(project_write_command("add", false))
        .subcommand(project_write_command("update", true))
        .subcommand(
            Command::new("delete")
                .arg(Arg::new("id").required(true))
                .arg(force_arg()),
        )
}

fn project_write_command(name: &'static str, needs_id: bool) -> Command {
    let mut command = Command::new(name)
        .arg(option("name", "name", "TEXT"))
        .arg(option("client", "client", "ID|none"))
        .arg(option("summary", "summary", "TEXT"))
        .arg(option("rate", "rate", "AMOUNT"))
        .arg(option("currency", "currency", "CODE"));
    if needs_id {
        command = command.arg(Arg::new("id").required(true));
    }
    command
}

fn payment_detail_command() -> Command {
    Command::new("payment-detail")
        .about("Manage payment acceptance details")
        .after_help(
            "Examples:\n  invoicegen-rs payment-detail list --query bank\n  invoicegen-rs payment-detail add --kind bank-details --label \"Primary bank\" --detail \"Account: 123\"\n  invoicegen-rs payment-detail delete PAYMENT_DETAIL_ID --force",
        )
        .subcommand(Command::new("list").arg(option("query", "query", "TEXT")))
        .subcommand(payment_detail_write_command("add", false))
        .subcommand(payment_detail_write_command("update", true))
        .subcommand(
            Command::new("delete")
                .arg(Arg::new("id").required(true))
                .arg(force_arg()),
        )
}

fn invoice_render_output_path(output_path: PathBuf, invoice: &Invoice) -> PathBuf {
    if output_path.is_dir() {
        output_path.join(invoice_pdf_file_name(invoice))
    } else {
        output_path
    }
}

fn payment_detail_write_command(name: &'static str, needs_id: bool) -> Command {
    let mut command = Command::new(name)
        .arg(
            option("kind", "kind", "bank-details|cryptocurrency")
                .value_parser(["bank-details", "cryptocurrency"]),
        )
        .arg(option("label", "label", "TEXT"))
        .arg(option("details", "details", "TEXT"))
        .arg(option("detail", "detail", "LINE").action(ArgAction::Append));
    if needs_id {
        command = command.arg(Arg::new("id").required(true));
    }
    command
}

fn invoice_command() -> Command {
    Command::new("invoice")
        .about("Manage invoices")
        .after_help(
            "Examples:\n  invoicegen-rs invoice list [--status STATUS]\n  invoicegen-rs invoice list --status overdue --format json\n  invoicegen-rs invoice render INV-2026-0001 --output ./exports",
        )
        .subcommand(Command::new("list")
            .arg(option("status", "status", "STATUS").value_parser(["draft", "sent", "paid", "overdue", "void"]))
            .arg(option("client", "client", "ID|none"))
            .arg(option("query", "query", "TEXT"))
            .arg(option("sort", "sort", "FIELD"))
            .arg(reverse_arg()))
        .subcommand(invoice_write_command("add", false))
        .subcommand(invoice_write_command("update", true))
        .subcommand(Command::new("delete")
            .arg(Arg::new("id-or-number").required(true))
            .arg(force_arg()))
        .subcommand(Command::new("add-item")
            .arg(Arg::new("id-or-number").required(true))
            .args(line_item_args()))
        .subcommand(Command::new("update-item")
            .arg(Arg::new("id-or-number").required(true))
            .arg(Arg::new("item-id").required(true))
            .args(line_item_args()))
        .subcommand(Command::new("delete-item")
            .arg(Arg::new("id-or-number").required(true))
            .arg(Arg::new("item-id").required(true))
            .arg(force_arg()))
        .subcommand(Command::new("mark-sent").arg(Arg::new("id-or-number").required(true)))
        .subcommand(Command::new("mark-paid")
            .arg(Arg::new("id-or-number").required(true))
            .arg(option("amount", "amount", "AMOUNT"))
            .arg(option("reference", "reference", "TEXT"))
            .arg(option("notes", "notes", "TEXT")))
        .subcommand(Command::new("mark-unpaid").arg(Arg::new("id-or-number").required(true)))
        .subcommand(Command::new("set-status")
            .arg(Arg::new("id-or-number").required(true))
            .arg(Arg::new("status").required(true).value_parser(["draft", "sent", "paid", "overdue", "void"])))
        .subcommand(Command::new("accept-payment")
            .arg(Arg::new("id-or-number").required(true))
            .arg(Arg::new("payment-detail-id").required(true)))
        .subcommand(Command::new("detach-payment")
            .arg(Arg::new("id-or-number").required(true))
            .arg(Arg::new("payment-detail-id").required(true)))
        .subcommand(Command::new("render")
            .arg(Arg::new("id-or-number").required(true))
            .arg(option("output", "output", "PATH")))
}

fn invoice_write_command(name: &'static str, needs_id: bool) -> Command {
    let mut command = Command::new(name)
        .arg(option("number", "number", "TEXT"))
        .arg(option("client", "client", "ID|none"))
        .arg(option("project", "project", "ID|none"))
        .arg(option("issue-date", "issue-date", "YYYY-MM-DD"))
        .arg(option("due-date", "due-date", "YYYY-MM-DD"))
        .arg(option("currency", "currency", "CODE"))
        .arg(option("notes", "notes", "TEXT"))
        .arg(option("terms", "terms", "TEXT"))
        .arg(
            option("status", "status", "STATUS")
                .value_parser(["draft", "sent", "paid", "overdue", "void"]),
        )
        .arg(
            Arg::new("no-default-item")
                .long("no-default-item")
                .action(ArgAction::SetTrue),
        );
    if needs_id {
        command = command.arg(Arg::new("id-or-number").required(true));
    }
    command
}

fn line_item_args() -> Vec<Arg> {
    vec![
        option("title", "title", "TEXT"),
        option("details", "details", "TEXT"),
        option("quantity", "quantity", "N"),
        option("unit-price", "unit-price", "AMOUNT"),
        option("tax-rate", "tax-rate", "N"),
    ]
}

fn option(id: &'static str, long: &'static str, value_name: &'static str) -> Arg {
    Arg::new(id).long(long).value_name(value_name).num_args(1)
}

fn force_arg() -> Arg {
    Arg::new("force")
        .long("force")
        .action(ArgAction::SetTrue)
        .help("Confirm a destructive operation")
}

fn reverse_arg() -> Arg {
    Arg::new("reverse")
        .long("reverse")
        .action(ArgAction::SetTrue)
        .help("Reverse the sort order")
}

fn command_completion(mut args: Vec<String>) -> Result<String, String> {
    let shell = next_arg(&mut args, "shell")?;
    reject_unknown(args)?;
    let shell = match shell.as_str() {
        "bash" => Shell::Bash,
        "zsh" => Shell::Zsh,
        "fish" => Shell::Fish,
        _ => {
            return Err(cli_error(
                "invalid_shell",
                format!("unsupported shell: {shell}"),
                Some("use one of: bash, zsh, fish".to_string()),
            ))
        }
    };
    let mut command = build_command();
    let mut buffer = Vec::new();
    generate(shell, &mut command, "invoicegen-rs", &mut buffer);
    String::from_utf8(buffer).map_err(|error| error.to_string())
}

fn format_clap_error(error: clap::Error) -> String {
    let text = error.to_string();
    if text.contains("a value is required") || text.contains("requires a value") {
        let option = first_long_option(&text).unwrap_or_else(|| "option".to_string());
        return cli_error(
            "missing_value",
            format!("{option} requires a value"),
            Some("run invoicegen-rs --help to inspect valid usage".to_string()),
        );
    }
    match error.kind() {
        clap::error::ErrorKind::InvalidSubcommand => cli_error(
            "unknown_command",
            compact_clap_message(&text),
            Some("run invoicegen-rs --help".to_string()),
        ),
        clap::error::ErrorKind::UnknownArgument => cli_error(
            "invalid_arguments",
            compact_clap_message(&text),
            Some("run invoicegen-rs --help".to_string()),
        ),
        _ => cli_error(
            "invalid_arguments",
            compact_clap_message(&text),
            Some("run invoicegen-rs --help".to_string()),
        ),
    }
}

fn first_long_option(text: &str) -> Option<String> {
    text.split_whitespace().find_map(|word| {
        let trimmed = word.trim_matches(|ch: char| {
            matches!(
                ch,
                '\'' | '"' | ',' | '.' | ':' | ';' | '<' | '>' | '[' | ']'
            )
        });
        trimmed.starts_with("--").then(|| trimmed.to_string())
    })
}

fn compact_clap_message(text: &str) -> String {
    text.lines()
        .find(|line| !line.trim().is_empty())
        .unwrap_or(text)
        .trim()
        .trim_start_matches("error: ")
        .to_string()
}

fn global_help() -> String {
    let mut command = build_command();
    command.render_help().to_string()
}

fn default_config_path() -> PathBuf {
    if let Ok(path) = env::var("INVOICEGEN_CONFIG") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let environment: Vec<(String, String)> = env::vars().collect();
    let get = |key: &str| {
        environment
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value)
    };
    match std::env::consts::OS {
        "macos" => get("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."))
            .join("Library")
            .join("Application Support")
            .join("InvoiceGen")
            .join("config.json"),
        "windows" => get("APPDATA")
            .or_else(|| get("LOCALAPPDATA"))
            .or_else(|| get("USERPROFILE"))
            .or_else(|| get("HOME"))
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."))
            .join("InvoiceGen")
            .join("config.json"),
        _ => get("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                get("HOME")
                    .map(PathBuf::from)
                    .unwrap_or_else(|| PathBuf::from("."))
                    .join(".config")
            })
            .join("invoicegen")
            .join("config.json"),
    }
}

fn take_global_config_path(args: &mut Vec<String>) -> Result<Option<PathBuf>, String> {
    take_global_path(args, "--config")
}

fn take_global_store_path(args: &mut Vec<String>) -> Result<Option<PathBuf>, String> {
    take_global_path(args, "--store")
}

fn take_global_path(args: &mut Vec<String>, option: &str) -> Result<Option<PathBuf>, String> {
    let mut path = None;
    let mut index = 0;
    while index < args.len() {
        if args[index] == option {
            if index + 1 >= args.len() {
                return Err(cli_error(
                    "missing_value",
                    format!("{option} requires a value"),
                    Some("run invoicegen-rs --help to inspect valid usage".to_string()),
                ));
            }
            path = Some(PathBuf::from(args.remove(index + 1)));
            args.remove(index);
            continue;
        }
        if args[index].starts_with('-') {
            index += 1;
            continue;
        }
        break;
    }
    Ok(path)
}

fn take_output_format(args: &mut Vec<String>) -> Result<Option<OutputFormat>, String> {
    take_option(args, "--format")
        .or_else(|| take_option(args, "--output-format"))
        .map(|value| OutputFormat::parse(&value))
        .transpose()
}

fn output_format_for(args: &mut Vec<String>, context: &CliContext) -> Result<OutputFormat, String> {
    let command_output = match take_output_format(args)? {
        Some(format) => Some(format),
        None => take_option(args, "--output")
            .map(|value| OutputFormat::parse(&value))
            .transpose()?,
    };
    Ok(command_output
        .or(context.global_format)
        .or(context.config.default_output)
        .unwrap_or(OutputFormat::Text))
}

fn require_force(force: bool) -> Result<(), String> {
    if force {
        Ok(())
    } else {
        Err(cli_error(
            "destructive_action_requires_force",
            "refusing to run a destructive action without confirmation",
            Some("pass --force to confirm".to_string()),
        ))
    }
}

fn format_profile(profile: &BusinessProfile, format: OutputFormat) -> Result<String, String> {
    match format {
        OutputFormat::Json => Ok(json_string(json::object([
            ("name".to_string(), json::string(&profile.name)),
            ("email".to_string(), json::string(&profile.email)),
            ("address".to_string(), json::string(&profile.address)),
            (
                "taxIdentifier".to_string(),
                json::string(&profile.tax_identifier),
            ),
            (
                "currencyCode".to_string(),
                json::string(&profile.currency_code),
            ),
            (
                "paymentTermsDays".to_string(),
                json::number(profile.payment_terms_days),
            ),
        ]))),
        OutputFormat::Csv => Ok(csv_rows(&["field", "value"], &profile_rows(profile))),
        OutputFormat::Tsv => Ok(tsv_rows(&["field", "value"], &profile_rows(profile))),
        OutputFormat::Text => Ok(render_profile(profile)),
    }
}

fn profile_rows(profile: &BusinessProfile) -> Vec<Vec<String>> {
    vec![
        vec!["name".to_string(), profile.name.clone()],
        vec!["email".to_string(), profile.email.clone()],
        vec!["address".to_string(), profile.address.clone()],
        vec!["taxIdentifier".to_string(), profile.tax_identifier.clone()],
        vec!["currencyCode".to_string(), profile.currency_code.clone()],
        vec![
            "paymentTermsDays".to_string(),
            profile.payment_terms_days.to_string(),
        ],
    ]
}

fn format_clients(clients: &[Client], format: OutputFormat) -> Result<String, String> {
    match format {
        OutputFormat::Json => Ok(json_string(JsonValue::Array(
            clients
                .iter()
                .map(|client| {
                    json::object([
                        ("id".to_string(), json::string(&client.id)),
                        ("name".to_string(), json::string(&client.name)),
                        ("email".to_string(), json::string(&client.email)),
                        ("company".to_string(), json::string(&client.company)),
                        ("address".to_string(), json::string(&client.address)),
                        ("notes".to_string(), json::string(&client.notes)),
                    ])
                })
                .collect(),
        ))),
        OutputFormat::Csv => Ok(csv_rows(
            &["id", "name", "email", "company"],
            &clients_table(clients),
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["id", "name", "email", "company"],
            &clients_table(clients),
        )),
        OutputFormat::Text => {
            let mut output = String::from("ID\tName\tEmail\tCompany\n");
            for row in clients_table(clients) {
                output.push_str(&format!("{}\t{}\t{}\t{}\n", row[0], row[1], row[2], row[3]));
            }
            Ok(output)
        }
    }
}

fn clients_table(clients: &[Client]) -> Vec<Vec<String>> {
    clients
        .iter()
        .map(|client| {
            vec![
                client.id.clone(),
                client.name.clone(),
                client.email.clone(),
                client.company.clone(),
            ]
        })
        .collect()
}

fn format_projects(
    projects: &[Project],
    book: &InvoiceBook,
    format: OutputFormat,
) -> Result<String, String> {
    match format {
        OutputFormat::Json => Ok(json_string(JsonValue::Array(
            projects
                .iter()
                .map(|project| {
                    let client = project_client_name(project, book);
                    let mut entries = BTreeMap::new();
                    entries.insert("id".to_string(), json::string(&project.id));
                    entries.insert("name".to_string(), json::string(&project.name));
                    entries.insert("client".to_string(), json::string(&client));
                    if let Some(client_id) = &project.client_id {
                        entries.insert("clientId".to_string(), json::string(client_id));
                    }
                    entries.insert(
                        "rate".to_string(),
                        json::string(format_money(
                            project.hourly_rate_minor_units,
                            &project.currency_code,
                        )),
                    );
                    entries.insert(
                        "hourlyRateMinorUnits".to_string(),
                        json::number(project.hourly_rate_minor_units),
                    );
                    entries.insert(
                        "currencyCode".to_string(),
                        json::string(&project.currency_code),
                    );
                    entries.insert("summary".to_string(), json::string(&project.summary));
                    JsonValue::Object(entries)
                })
                .collect(),
        ))),
        OutputFormat::Csv => Ok(csv_rows(
            &["id", "name", "client", "rate"],
            &projects_table(projects, book),
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["id", "name", "client", "rate"],
            &projects_table(projects, book),
        )),
        OutputFormat::Text => {
            let mut output = String::from("ID\tName\tClient\tRate\n");
            for row in projects_table(projects, book) {
                output.push_str(&format!("{}\t{}\t{}\t{}\n", row[0], row[1], row[2], row[3]));
            }
            Ok(output)
        }
    }
}

fn projects_table(projects: &[Project], book: &InvoiceBook) -> Vec<Vec<String>> {
    projects
        .iter()
        .map(|project| {
            vec![
                project.id.clone(),
                project.name.clone(),
                project_client_name(project, book),
                format_money(project.hourly_rate_minor_units, &project.currency_code),
            ]
        })
        .collect()
}

fn project_client_name(project: &Project, book: &InvoiceBook) -> String {
    project
        .client_id
        .as_ref()
        .and_then(|id| book.clients.iter().find(|client| &client.id == id))
        .map(|client| client.name.clone())
        .unwrap_or_else(|| "No client".to_string())
}

fn format_payment_details(
    details: &[PaymentAcceptanceDetail],
    format: OutputFormat,
) -> Result<String, String> {
    match format {
        OutputFormat::Json => Ok(json_string(JsonValue::Array(
            details
                .iter()
                .map(|detail| {
                    json::object([
                        ("id".to_string(), json::string(&detail.id)),
                        ("kind".to_string(), json::string(detail.kind.raw_value())),
                        ("label".to_string(), json::string(&detail.label)),
                        ("details".to_string(), json::string(&detail.details)),
                    ])
                })
                .collect(),
        ))),
        OutputFormat::Csv => Ok(csv_rows(
            &["id", "kind", "label"],
            &payment_details_table(details),
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["id", "kind", "label"],
            &payment_details_table(details),
        )),
        OutputFormat::Text => {
            let mut output = String::from("ID\tKind\tLabel\n");
            for row in payment_details_table(details) {
                output.push_str(&format!("{}\t{}\t{}\n", row[0], row[1], row[2]));
            }
            Ok(output)
        }
    }
}

fn payment_details_table(details: &[PaymentAcceptanceDetail]) -> Vec<Vec<String>> {
    details
        .iter()
        .map(|detail| {
            vec![
                detail.id.clone(),
                detail.kind.label().to_string(),
                detail.label.clone(),
            ]
        })
        .collect()
}

fn format_invoices(
    invoices: &[Invoice],
    book: &InvoiceBook,
    format: OutputFormat,
) -> Result<String, String> {
    match format {
        OutputFormat::Json => Ok(json_string(JsonValue::Array(
            invoices
                .iter()
                .map(|invoice| {
                    let client = invoice_client_name(invoice, book);
                    let mut entries = BTreeMap::new();
                    entries.insert("id".to_string(), json::string(&invoice.id));
                    entries.insert("number".to_string(), json::string(&invoice.number));
                    entries.insert("client".to_string(), json::string(&client));
                    if let Some(client_id) = &invoice.client_id {
                        entries.insert("clientId".to_string(), json::string(client_id));
                    }
                    entries.insert(
                        "status".to_string(),
                        json::string(invoice.status.raw_value()),
                    );
                    entries.insert(
                        "balance".to_string(),
                        json::string(format_money(
                            invoice.balance_due_minor_units(),
                            &invoice.currency_code,
                        )),
                    );
                    entries.insert(
                        "balanceMinorUnits".to_string(),
                        json::number(invoice.balance_due_minor_units()),
                    );
                    entries.insert("dueDate".to_string(), json::string(&invoice.due_date));
                    entries.insert("issueDate".to_string(), json::string(&invoice.issue_date));
                    entries.insert(
                        "currencyCode".to_string(),
                        json::string(&invoice.currency_code),
                    );
                    JsonValue::Object(entries)
                })
                .collect(),
        ))),
        OutputFormat::Csv => Ok(csv_rows(
            &["id", "number", "client", "status", "balance", "due"],
            &invoices_table(invoices, book),
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["id", "number", "client", "status", "balance", "due"],
            &invoices_table(invoices, book),
        )),
        OutputFormat::Text => {
            let mut output = String::from("ID\tNumber\tClient\tStatus\tBalance\tDue\n");
            for row in invoices_table(invoices, book) {
                output.push_str(&format!(
                    "{}\t{}\t{}\t{}\t{}\t{}\n",
                    row[0], row[1], row[2], row[3], row[4], row[5]
                ));
            }
            Ok(output)
        }
    }
}

fn invoices_table(invoices: &[Invoice], book: &InvoiceBook) -> Vec<Vec<String>> {
    invoices
        .iter()
        .map(|invoice| {
            vec![
                invoice.id.clone(),
                invoice.number.clone(),
                invoice_client_name(invoice, book),
                invoice.status.label().to_string(),
                format_money(invoice.balance_due_minor_units(), &invoice.currency_code),
                invoice.due_date.clone(),
            ]
        })
        .collect()
}

fn invoice_client_name(invoice: &Invoice, book: &InvoiceBook) -> String {
    book.client_for(invoice)
        .map(|client| client.name.clone())
        .unwrap_or_else(|| "Unassigned client".to_string())
}

fn format_config(config: &CliConfig, path: &Path, format: OutputFormat) -> Result<String, String> {
    let store_path = config
        .store_path
        .as_ref()
        .map(|path| path.display().to_string())
        .unwrap_or_default();
    let default_output = config
        .default_output
        .map(OutputFormat::as_str)
        .unwrap_or("text");
    match format {
        OutputFormat::Json => Ok(json_string(json::object([
            (
                "configPath".to_string(),
                json::string(path.display().to_string()),
            ),
            ("storePath".to_string(), json::string(store_path)),
            ("defaultOutput".to_string(), json::string(default_output)),
        ]))),
        OutputFormat::Csv => Ok(csv_rows(
            &["setting", "value"],
            &[
                vec!["configPath".to_string(), path.display().to_string()],
                vec!["storePath".to_string(), store_path],
                vec!["defaultOutput".to_string(), default_output.to_string()],
            ],
        )),
        OutputFormat::Tsv => Ok(tsv_rows(
            &["setting", "value"],
            &[
                vec!["configPath".to_string(), path.display().to_string()],
                vec!["storePath".to_string(), store_path],
                vec!["defaultOutput".to_string(), default_output.to_string()],
            ],
        )),
        OutputFormat::Text => Ok(format!(
            "Config: {}\nStore: {}\nDefault Output: {}\n",
            path.display(),
            if store_path.is_empty() {
                "default"
            } else {
                &store_path
            },
            default_output
        )),
    }
}

fn json_string(value: JsonValue) -> String {
    json::stringify_pretty(&value)
}

fn csv_rows(headers: &[&str], rows: &[Vec<String>]) -> String {
    let mut output = String::new();
    output.push_str(
        &headers
            .iter()
            .map(|field| csv_field(field))
            .collect::<Vec<_>>()
            .join(","),
    );
    output.push('\n');
    for row in rows {
        output.push_str(
            &row.iter()
                .map(|field| csv_field(field))
                .collect::<Vec<_>>()
                .join(","),
        );
        output.push('\n');
    }
    output
}

fn csv_field(value: &str) -> String {
    if value.contains([',', '"', '\n', '\r']) {
        format!("\"{}\"", value.replace('"', "\"\""))
    } else {
        value.to_string()
    }
}

fn tsv_rows(headers: &[&str], rows: &[Vec<String>]) -> String {
    let mut output = String::new();
    output.push_str(&headers.join("\t"));
    output.push('\n');
    for row in rows {
        output.push_str(
            &row.iter()
                .map(|field| tsv_field(field))
                .collect::<Vec<_>>()
                .join("\t"),
        );
        output.push('\n');
    }
    output
}

fn tsv_field(value: &str) -> String {
    value.replace(['\t', '\n', '\r'], " ")
}

fn contains_ci(value: &str, lower_query: &str) -> bool {
    value.to_lowercase().contains(lower_query)
}

fn cli_error(code: &str, message: impl AsRef<str>, hint: Option<String>) -> String {
    let mut output = format!("error: {code}\nmessage: {}\n", message.as_ref());
    if let Some(hint) = hint {
        output.push_str(&format!("hint: {hint}\n"));
    }
    output
}

fn structure_unstructured_error(error: String) -> String {
    if error.starts_with("error: ") {
        return error;
    }
    let code = if error.starts_with("unexpected arguments") {
        "invalid_arguments"
    } else if error.starts_with("missing ") {
        "missing_argument"
    } else if error.contains("not found") {
        "not_found"
    } else if error.starts_with("invalid ") || error.starts_with("Invalid ") {
        "invalid_value"
    } else if error.starts_with("failed ") {
        "io_error"
    } else {
        "command_failed"
    };
    cli_error(code, error, None)
}

fn take_option(args: &mut Vec<String>, option: &str) -> Option<String> {
    let index = args.iter().position(|arg| arg == option)?;
    if index + 1 >= args.len() {
        return Some(String::new());
    }
    let value = args.remove(index + 1);
    args.remove(index);
    Some(value)
}

fn take_all_options(args: &mut Vec<String>, option: &str) -> Vec<String> {
    let mut values = Vec::new();
    while let Some(value) = take_option(args, option) {
        values.push(value);
    }
    values
}

fn take_flag(args: &mut Vec<String>, flag: &str) -> bool {
    if let Some(index) = args.iter().position(|arg| arg == flag) {
        args.remove(index);
        true
    } else {
        false
    }
}

fn next_arg(args: &mut Vec<String>, name: &str) -> Result<String, String> {
    if args.is_empty() {
        Err(format!("missing {name}"))
    } else {
        Ok(args.remove(0))
    }
}

fn reject_unknown(args: Vec<String>) -> Result<(), String> {
    if args.is_empty() {
        Ok(())
    } else {
        Err(format!("unexpected arguments: {}", args.join(" ")))
    }
}

fn parse_i64(value: &str, name: &str) -> Result<i64, String> {
    value
        .parse()
        .map_err(|_| format!("invalid integer for {name}: {value}"))
}

fn parse_f64(value: &str, name: &str) -> Result<f64, String> {
    value
        .parse()
        .map_err(|_| format!("invalid number for {name}: {value}"))
}
