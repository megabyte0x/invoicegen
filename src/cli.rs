use crate::domain::{
    add_days_iso, format_money, normalize_date_input, now_iso, parse_minor_units,
    render_invoice_text, BusinessProfile, Client, Invoice, InvoiceBook, InvoiceLineItem,
    InvoiceStatus, Payment, PaymentAcceptanceDetail, PaymentAcceptanceKind, Project,
};
use crate::store::LocalInvoiceStore;
use std::fs;
use std::path::PathBuf;

pub fn run_cli(args: impl IntoIterator<Item = String>) -> Result<String, String> {
    let mut args: Vec<String> = args.into_iter().collect();
    let store_path = take_global_store_path(&mut args)?;
    if args.is_empty() || take_flag(&mut args, "--help") || take_flag(&mut args, "-h") {
        return Ok(help());
    }

    let command = args.remove(0);
    let store = LocalInvoiceStore::new(store_path);
    match command.as_str() {
        "store" => command_store(store, args),
        "seed-sample" => command_seed_sample(store, args),
        "summary" => command_summary(store, args),
        "profile" => command_profile(store, args),
        "client" => command_client(store, args),
        "project" => command_project(store, args),
        "payment-detail" => command_payment_detail(store, args),
        "invoice" => command_invoice(store, args),
        _ => Err(format!("unknown command: {command}\n\n{}", help())),
    }
}

fn command_store(store: LocalInvoiceStore, args: Vec<String>) -> Result<String, String> {
    let subcommand = args.first().map(String::as_str).unwrap_or("path");
    match subcommand {
        "path" => Ok(format!("{}\n", store.path.display())),
        _ => Err(format!("unknown store command: {subcommand}")),
    }
}

fn command_seed_sample(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let force = take_flag(&mut args, "--force");
    reject_unknown(args)?;
    if store.path.exists() && !force {
        return Err("store already exists; pass --force to replace it".to_string());
    }
    let now = now_iso();
    let book = InvoiceBook::sample(&now);
    store.save(&book)?;
    Ok(format!("Seeded sample data at {}\n", store.path.display()))
}

fn command_summary(store: LocalInvoiceStore, args: Vec<String>) -> Result<String, String> {
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
    Ok(format!(
        "Outstanding: {}\nPaid to Date: {}\nTotal Clients: {}\nOverdue Invoices: {}\nStore: {}\n",
        format_money(outstanding, &book.business_profile.currency_code),
        format_money(paid, &book.business_profile.currency_code),
        book.clients.len(),
        overdue,
        store.path.display()
    ))
}

fn command_profile(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "profile command")?;
    match subcommand.as_str() {
        "show" => {
            reject_unknown(args)?;
            let book = store.load()?;
            Ok(render_profile(&book.business_profile))
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

fn command_client(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "client command")?;
    match subcommand.as_str() {
        "list" => {
            reject_unknown(args)?;
            let mut clients = store.load()?.clients;
            clients.sort_by(|left, right| left.name.to_lowercase().cmp(&right.name.to_lowercase()));
            let mut output = String::from("ID\tName\tEmail\tCompany\n");
            for client in clients {
                output.push_str(&format!(
                    "{}\t{}\t{}\t{}\n",
                    client.id, client.name, client.email, client.company
                ));
            }
            Ok(output)
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
            reject_unknown(args)?;
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

fn command_project(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "project command")?;
    match subcommand.as_str() {
        "list" => {
            reject_unknown(args)?;
            let book = store.load()?;
            let mut projects = book.projects.clone();
            projects
                .sort_by(|left, right| left.name.to_lowercase().cmp(&right.name.to_lowercase()));
            let mut output = String::from("ID\tName\tClient\tRate\n");
            for project in projects {
                let client = project
                    .client_id
                    .as_ref()
                    .and_then(|id| book.clients.iter().find(|client| &client.id == id))
                    .map(|client| client.name.as_str())
                    .unwrap_or("No client");
                output.push_str(&format!(
                    "{}\t{}\t{}\t{}\n",
                    project.id,
                    project.name,
                    client,
                    format_money(project.hourly_rate_minor_units, &project.currency_code)
                ));
            }
            Ok(output)
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
            reject_unknown(args)?;
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
    store: LocalInvoiceStore,
    mut args: Vec<String>,
) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "payment-detail command")?;
    match subcommand.as_str() {
        "list" => {
            reject_unknown(args)?;
            let book = store.load()?;
            let mut output = String::from("ID\tKind\tLabel\n");
            for detail in book.payment_acceptance_details {
                output.push_str(&format!(
                    "{}\t{}\t{}\n",
                    detail.id,
                    detail.kind.label(),
                    detail.label
                ));
            }
            Ok(output)
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
            reject_unknown(args)?;
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

fn command_invoice(store: LocalInvoiceStore, mut args: Vec<String>) -> Result<String, String> {
    let subcommand = next_arg(&mut args, "invoice command")?;
    match subcommand.as_str() {
        "list" => {
            reject_unknown(args)?;
            let book = store.load()?;
            let mut invoices = book.invoices.clone();
            invoices.sort_by(|left, right| right.issue_date.cmp(&left.issue_date));
            let mut output = String::from("ID\tNumber\tClient\tStatus\tBalance\tDue\n");
            for invoice in invoices {
                let client = book
                    .client_for(&invoice)
                    .map(|client| client.name.as_str())
                    .unwrap_or("Unassigned client");
                output.push_str(&format!(
                    "{}\t{}\t{}\t{}\t{}\t{}\n",
                    invoice.id,
                    invoice.number,
                    client,
                    invoice.status.label(),
                    format_money(invoice.balance_due_minor_units(), &invoice.currency_code),
                    invoice.due_date
                ));
            }
            Ok(output)
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
            reject_unknown(args)?;
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
            reject_unknown(args)?;
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
            let rendered = render_invoice_text(&book.invoices[index], &book);
            if let Some(output_path) = output_path {
                fs::write(&output_path, &rendered).map_err(|error| {
                    format!("failed to write {}: {error}", output_path.display())
                })?;
                Ok(format!("Wrote {}\n", output_path.display()))
            } else {
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

fn take_global_store_path(args: &mut Vec<String>) -> Result<Option<PathBuf>, String> {
    let mut store_path = None;
    while let Some(index) = args.iter().position(|arg| arg == "--store") {
        if index + 1 >= args.len() {
            return Err("--store requires a path".to_string());
        }
        store_path = Some(PathBuf::from(args.remove(index + 1)));
        args.remove(index);
    }
    Ok(store_path)
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

fn help() -> String {
    let text = r#"InvoiceGen Rust CLI

Usage:
  invoicegen-rs [--store PATH] <command> [args]

Commands:
  store path
  seed-sample --force
  summary
  profile show
  profile set [--name TEXT] [--email TEXT] [--address TEXT] [--tax-id TEXT] [--currency CODE] [--terms-days N]
  client list
  client add [--name TEXT] [--company TEXT] [--email TEXT] [--address TEXT] [--notes TEXT]
  client update <id> [same options as add]
  client delete <id>
  project list
  project add [--name TEXT] [--client ID|none] [--summary TEXT] [--rate AMOUNT] [--currency CODE]
  project update <id> [same options as add]
  project delete <id>
  payment-detail list
  payment-detail add --kind bank-details|cryptocurrency [--label TEXT] [--detail LINE ...]
  payment-detail update <id> [--kind bank-details|cryptocurrency] [--label TEXT] [--details TEXT] [--detail LINE ...]
  payment-detail delete <id>
  invoice list
  invoice add [--number TEXT] [--client ID|none] [--project ID|none] [--issue-date YYYY-MM-DD] [--due-date YYYY-MM-DD] [--currency CODE] [--notes TEXT] [--terms TEXT] [--status draft|sent|paid|overdue|void] [--no-default-item]
  invoice update <id|number> [same options as add except --no-default-item]
  invoice delete <id|number>
  invoice add-item <id|number> [--title TEXT] [--details TEXT] [--quantity N] [--unit-price AMOUNT] [--tax-rate N]
  invoice update-item <id|number> <item-id> [same options as add-item]
  invoice delete-item <id|number> <item-id>
  invoice mark-sent <id|number>
  invoice mark-paid <id|number> [--amount AMOUNT] [--reference TEXT] [--notes TEXT]
  invoice mark-unpaid <id|number>
  invoice set-status <id|number> draft|sent|paid|overdue|void
  invoice accept-payment <id|number> <payment-detail-id>
  invoice detach-payment <id|number> <payment-detail-id>
  invoice render <id|number> [--output PATH]
"#;
    text.to_string()
}
