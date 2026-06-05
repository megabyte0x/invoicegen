use crate::json::{self, JsonValue};
use std::collections::BTreeMap;
use std::fs::File;
use std::io::Read;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

pub const CURRENT_SCHEMA_VERSION: i64 = 2;

static ID_COUNTER: AtomicU64 = AtomicU64::new(1);

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum InvoiceStatus {
    Draft,
    Sent,
    Paid,
    Overdue,
    Void,
}

impl InvoiceStatus {
    pub fn raw_value(&self) -> &'static str {
        match self {
            InvoiceStatus::Draft => "draft",
            InvoiceStatus::Sent => "sent",
            InvoiceStatus::Paid => "paid",
            InvoiceStatus::Overdue => "overdue",
            InvoiceStatus::Void => "void",
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            InvoiceStatus::Draft => "Draft",
            InvoiceStatus::Sent => "Sent",
            InvoiceStatus::Paid => "Paid",
            InvoiceStatus::Overdue => "Overdue",
            InvoiceStatus::Void => "Void",
        }
    }

    pub fn parse(value: &str) -> Result<Self, String> {
        match value {
            "draft" => Ok(InvoiceStatus::Draft),
            "sent" => Ok(InvoiceStatus::Sent),
            "paid" => Ok(InvoiceStatus::Paid),
            "overdue" => Ok(InvoiceStatus::Overdue),
            "void" => Ok(InvoiceStatus::Void),
            _ => Err(format!("unknown invoice status: {value}")),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PaymentAcceptanceKind {
    BankDetails,
    Cryptocurrency,
}

impl PaymentAcceptanceKind {
    pub fn raw_value(&self) -> &'static str {
        match self {
            PaymentAcceptanceKind::BankDetails => "bankDetails",
            PaymentAcceptanceKind::Cryptocurrency => "cryptocurrency",
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            PaymentAcceptanceKind::BankDetails => "Bank Details",
            PaymentAcceptanceKind::Cryptocurrency => "Cryptocurrency",
        }
    }

    pub fn parse(value: &str) -> Result<Self, String> {
        match value {
            "bankDetails" | "bank-details" | "bank" => Ok(PaymentAcceptanceKind::BankDetails),
            "cryptocurrency" | "crypto" => Ok(PaymentAcceptanceKind::Cryptocurrency),
            _ => Err(format!("unknown payment detail kind: {value}")),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BusinessProfile {
    pub name: String,
    pub email: String,
    pub address: String,
    pub tax_identifier: String,
    pub currency_code: String,
    pub payment_terms_days: i64,
}

impl Default for BusinessProfile {
    fn default() -> Self {
        Self {
            name: "My Business".to_string(),
            email: String::new(),
            address: String::new(),
            tax_identifier: String::new(),
            currency_code: "USD".to_string(),
            payment_terms_days: 14,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Client {
    pub id: String,
    pub name: String,
    pub company: String,
    pub email: String,
    pub address: String,
    pub notes: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Project {
    pub id: String,
    pub client_id: Option<String>,
    pub name: String,
    pub summary: String,
    pub hourly_rate_minor_units: i64,
    pub currency_code: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct InvoiceLineItem {
    pub id: String,
    pub title: String,
    pub details: String,
    pub quantity: f64,
    pub unit_price_minor_units: i64,
    pub tax_rate_percent: f64,
}

impl InvoiceLineItem {
    pub fn subtotal_minor_units(&self) -> i64 {
        (self.quantity * self.unit_price_minor_units as f64).round() as i64
    }

    pub fn tax_minor_units(&self) -> i64 {
        (self.subtotal_minor_units() as f64 * self.tax_rate_percent / 100.0).round() as i64
    }

    pub fn total_minor_units(&self) -> i64 {
        self.subtotal_minor_units() + self.tax_minor_units()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct PaymentAcceptanceDetail {
    pub id: String,
    pub kind: PaymentAcceptanceKind,
    pub label: String,
    pub details: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Payment {
    pub id: String,
    pub amount_minor_units: i64,
    pub paid_at: String,
    pub reference: String,
    pub notes: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct InvoiceAutoGenerationSettings {
    pub is_enabled: bool,
    pub interval_days: i64,
    pub next_generation_date: String,
}

impl InvoiceAutoGenerationSettings {
    pub const MAXIMUM_INTERVAL_DAYS: i64 = 3_650;

    pub fn disabled() -> Self {
        Self {
            is_enabled: false,
            interval_days: 30,
            next_generation_date: "1970-01-01T00:00:00Z".to_string(),
        }
    }

    pub fn normalized_interval_days(value: i64) -> i64 {
        value.clamp(1, Self::MAXIMUM_INTERVAL_DAYS)
    }

    pub fn next_generation_date(interval_days: i64, from: &str) -> String {
        add_days_iso(from, Self::normalized_interval_days(interval_days))
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Invoice {
    pub id: String,
    pub number: String,
    pub client_id: Option<String>,
    pub project_id: Option<String>,
    pub issue_date: String,
    pub due_date: String,
    pub status: InvoiceStatus,
    pub currency_code: String,
    pub line_items: Vec<InvoiceLineItem>,
    pub payments: Vec<Payment>,
    pub notes: String,
    pub terms: String,
    pub accepted_payment_detail_ids: Vec<String>,
    pub auto_generation: InvoiceAutoGenerationSettings,
    pub created_at: String,
    pub updated_at: String,
}

impl Invoice {
    pub fn subtotal_minor_units(&self) -> i64 {
        self.line_items
            .iter()
            .map(InvoiceLineItem::subtotal_minor_units)
            .sum()
    }

    pub fn tax_minor_units(&self) -> i64 {
        self.line_items
            .iter()
            .map(InvoiceLineItem::tax_minor_units)
            .sum()
    }

    pub fn total_minor_units(&self) -> i64 {
        self.subtotal_minor_units() + self.tax_minor_units()
    }

    pub fn paid_minor_units(&self) -> i64 {
        self.payments
            .iter()
            .map(|payment| payment.amount_minor_units)
            .sum()
    }

    pub fn balance_due_minor_units(&self) -> i64 {
        0.max(self.total_minor_units() - self.paid_minor_units())
    }

    pub fn refresh_status(&mut self, now: &str) {
        if self.status == InvoiceStatus::Void {
            return;
        }
        if self.total_minor_units() > 0 && self.paid_minor_units() >= self.total_minor_units() {
            self.status = InvoiceStatus::Paid;
        } else if matches!(
            self.status,
            InvoiceStatus::Sent | InvoiceStatus::Overdue | InvoiceStatus::Paid
        ) {
            self.status = if date_before(&self.due_date, now) {
                InvoiceStatus::Overdue
            } else {
                InvoiceStatus::Sent
            };
        }
        self.updated_at = now.to_string();
    }

    pub fn mark_unpaid(&mut self, now: &str) {
        if self.status == InvoiceStatus::Void {
            return;
        }
        self.payments.clear();
        self.status = if date_before(&self.due_date, now) {
            InvoiceStatus::Overdue
        } else {
            InvoiceStatus::Sent
        };
        self.updated_at = now.to_string();
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct InvoiceBook {
    pub schema_version: i64,
    pub business_profile: BusinessProfile,
    pub clients: Vec<Client>,
    pub projects: Vec<Project>,
    pub payment_acceptance_details: Vec<PaymentAcceptanceDetail>,
    pub invoices: Vec<Invoice>,
}

impl InvoiceBook {
    pub fn empty() -> Self {
        Self {
            schema_version: CURRENT_SCHEMA_VERSION,
            business_profile: BusinessProfile::default(),
            clients: Vec::new(),
            projects: Vec::new(),
            payment_acceptance_details: Vec::new(),
            invoices: Vec::new(),
        }
    }

    pub fn sample(now: &str) -> Self {
        let client_a = Client {
            id: new_id(),
            name: "Northstar Studio".to_string(),
            company: "Northstar Studio LLC".to_string(),
            email: "accounts@northstar.example".to_string(),
            address: "12 Market Street\nSan Francisco, CA".to_string(),
            notes: "Prefers monthly billing with itemized project notes.".to_string(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        };
        let client_b = Client {
            id: new_id(),
            name: "Avery Patel".to_string(),
            company: "Patel Works".to_string(),
            email: "avery@patel.example".to_string(),
            address: "88 Lake Road\nAustin, TX".to_string(),
            notes: "Pays by bank transfer.".to_string(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        };
        let project = Project {
            id: new_id(),
            client_id: Some(client_a.id.clone()),
            name: "Brand refresh".to_string(),
            summary: "Identity system, landing page direction, and launch assets.".to_string(),
            hourly_rate_minor_units: 12_500,
            currency_code: "USD".to_string(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        };
        let bank_details = PaymentAcceptanceDetail {
            id: new_id(),
            kind: PaymentAcceptanceKind::BankDetails,
            label: "Primary business account".to_string(),
            details: "Bank: Example Federal Bank\nAccount: 123456789\nRouting: 987654321"
                .to_string(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        };
        let crypto_details = PaymentAcceptanceDetail {
            id: new_id(),
            kind: PaymentAcceptanceKind::Cryptocurrency,
            label: "USDC wallet".to_string(),
            details: "USDC on Base: 0x1234abcd5678ef901234abcd5678ef901234abcd".to_string(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        };
        let year = year_from_date(now).unwrap_or(1970);
        let mut book = Self {
            schema_version: CURRENT_SCHEMA_VERSION,
            business_profile: BusinessProfile {
                name: "Local Invoice Creative".to_string(),
                email: "hello@localinvoice.local".to_string(),
                address: "Local-only business profile".to_string(),
                tax_identifier: "TAX-LOCAL".to_string(),
                currency_code: "USD".to_string(),
                payment_terms_days: 14,
            },
            clients: vec![client_a.clone(), client_b.clone()],
            projects: vec![project.clone()],
            payment_acceptance_details: vec![bank_details.clone(), crypto_details.clone()],
            invoices: vec![
                Invoice {
                    id: new_id(),
                    number: format!("INV-{year}-0001"),
                    client_id: Some(client_a.id.clone()),
                    project_id: Some(project.id.clone()),
                    issue_date: now.to_string(),
                    due_date: add_days_iso(now, 14),
                    status: InvoiceStatus::Sent,
                    currency_code: "USD".to_string(),
                    line_items: vec![
                        InvoiceLineItem {
                            id: new_id(),
                            title: "Discovery workshop".to_string(),
                            details: "Stakeholder interviews and synthesis".to_string(),
                            quantity: 1.0,
                            unit_price_minor_units: 150_000,
                            tax_rate_percent: 0.0,
                        },
                        InvoiceLineItem {
                            id: new_id(),
                            title: "Design direction".to_string(),
                            details: "Visual territory and component starter kit".to_string(),
                            quantity: 1.0,
                            unit_price_minor_units: 280_000,
                            tax_rate_percent: 0.0,
                        },
                    ],
                    payments: Vec::new(),
                    notes: "Thank you for the continued partnership.".to_string(),
                    terms: "Net 14.".to_string(),
                    accepted_payment_detail_ids: vec![
                        bank_details.id.clone(),
                        crypto_details.id.clone(),
                    ],
                    auto_generation: InvoiceAutoGenerationSettings::disabled(),
                    created_at: now.to_string(),
                    updated_at: now.to_string(),
                },
                Invoice {
                    id: new_id(),
                    number: format!("INV-{year}-0002"),
                    client_id: Some(client_b.id.clone()),
                    project_id: None,
                    issue_date: add_days_iso(now, -18),
                    due_date: add_days_iso(now, -4),
                    status: InvoiceStatus::Sent,
                    currency_code: "USD".to_string(),
                    line_items: vec![InvoiceLineItem {
                        id: new_id(),
                        title: "Retainer".to_string(),
                        details: "June advisory retainer".to_string(),
                        quantity: 1.0,
                        unit_price_minor_units: 220_000,
                        tax_rate_percent: 0.0,
                    }],
                    payments: Vec::new(),
                    notes: String::new(),
                    terms: "Net 14.".to_string(),
                    accepted_payment_detail_ids: vec![bank_details.id.clone()],
                    auto_generation: InvoiceAutoGenerationSettings::disabled(),
                    created_at: now.to_string(),
                    updated_at: now.to_string(),
                },
            ],
        };
        book.refresh_invoice_statuses(now);
        book
    }

    pub fn refresh_invoice_statuses(&mut self, now: &str) {
        for invoice in &mut self.invoices {
            invoice.refresh_status(now);
        }
    }

    pub fn client_for(&self, invoice: &Invoice) -> Option<&Client> {
        invoice
            .client_id
            .as_ref()
            .and_then(|client_id| self.clients.iter().find(|client| &client.id == client_id))
    }

    pub fn project_for(&self, invoice: &Invoice) -> Option<&Project> {
        invoice.project_id.as_ref().and_then(|project_id| {
            self.projects
                .iter()
                .find(|project| &project.id == project_id)
        })
    }

    pub fn payment_acceptance_details_for(
        &self,
        invoice: &Invoice,
    ) -> Vec<&PaymentAcceptanceDetail> {
        invoice
            .accepted_payment_detail_ids
            .iter()
            .filter_map(|id| {
                self.payment_acceptance_details
                    .iter()
                    .find(|detail| &detail.id == id)
            })
            .collect()
    }

    pub fn next_invoice_number(&self, date: &str) -> String {
        let year = year_from_date(date).unwrap_or(1970);
        let prefix = format!("INV-{year}-");
        let max_sequence = self
            .invoices
            .iter()
            .filter_map(|invoice| invoice.number.strip_prefix(&prefix))
            .filter_map(|suffix| suffix.parse::<i64>().ok())
            .max()
            .unwrap_or(0);
        format!("{prefix}{:04}", max_sequence + 1)
    }

    pub fn generate_automatic_invoices(&mut self, now: &str) -> Vec<Invoice> {
        self.generate_automatic_invoices_with_limit(now, 24)
    }

    pub fn generate_automatic_invoices_with_limit(
        &mut self,
        now: &str,
        max_catch_up_per_invoice: usize,
    ) -> Vec<Invoice> {
        if max_catch_up_per_invoice == 0 {
            return Vec::new();
        }

        let original_invoice_count = self.invoices.len();
        let mut generated_invoices = Vec::new();

        for index in 0..original_invoice_count {
            if !self.invoices[index].auto_generation.is_enabled {
                continue;
            }

            let mut next_generation_date = self.invoices[index]
                .auto_generation
                .next_generation_date
                .clone();
            let mut generated_count = 0;

            while !date_before(now, &next_generation_date)
                && generated_count < max_catch_up_per_invoice
            {
                let source_invoice = self.invoices[index].clone();
                let generated_invoice = automatic_invoice_copy(
                    &source_invoice,
                    self.next_invoice_number(&next_generation_date),
                    &next_generation_date,
                    now,
                );
                self.invoices.push(generated_invoice.clone());
                generated_invoices.push(generated_invoice);
                generated_count += 1;

                next_generation_date = InvoiceAutoGenerationSettings::next_generation_date(
                    source_invoice.auto_generation.interval_days,
                    &next_generation_date,
                );
            }

            if generated_count > 0 {
                self.invoices[index].auto_generation.next_generation_date = next_generation_date;
                self.invoices[index].updated_at = now.to_string();
            }
        }

        generated_invoices
    }

    pub fn validate_for_save(&self) -> Result<(), String> {
        let mut issues = Vec::new();

        if !is_valid_currency_code(&self.business_profile.currency_code) {
            issues.push(
                "Business profile currency must be a three-letter uppercase code".to_string(),
            );
        }
        if !(0..=120).contains(&self.business_profile.payment_terms_days) {
            issues.push("Payment terms must be between 0 and 120 days".to_string());
        }

        for project in &self.projects {
            if let Some(client_id) = &project.client_id {
                if !self.clients.iter().any(|client| &client.id == client_id) {
                    issues.push(format!(
                        "Project references a missing client: {}",
                        project.name
                    ));
                }
            }
            if !is_valid_currency_code(&project.currency_code) {
                issues.push(format!(
                    "Project currency must be a three-letter uppercase code for project {}",
                    project.name
                ));
            }
            if project.hourly_rate_minor_units < 0 {
                issues.push(format!(
                    "Project hourly rate cannot be negative for project {}",
                    project.name
                ));
            }
        }

        let mut seen_invoice_numbers = BTreeMap::new();
        for invoice in &self.invoices {
            let trimmed_number = invoice.number.trim();
            if trimmed_number.is_empty() {
                issues.push("Invoice number is required".to_string());
            } else {
                let normalized_number = trimmed_number.to_lowercase();
                if seen_invoice_numbers.contains_key(&normalized_number) {
                    issues.push(format!("Invoice number must be unique: {trimmed_number}"));
                } else {
                    seen_invoice_numbers.insert(normalized_number, invoice.id.clone());
                }
            }

            if date_before(&invoice.due_date, &invoice.issue_date) {
                issues.push(format!(
                    "Due date cannot be before issue date for invoice {}",
                    invoice_display_number(invoice)
                ));
            }
            if invoice.auto_generation.is_enabled
                && !(1..=InvoiceAutoGenerationSettings::MAXIMUM_INTERVAL_DAYS)
                    .contains(&invoice.auto_generation.interval_days)
            {
                issues.push(format!(
                    "Automatic generation interval must be between 1 and 3650 days for invoice {}",
                    invoice_display_number(invoice)
                ));
            }
            if !is_valid_currency_code(&invoice.currency_code) {
                issues.push(format!(
                    "Invoice currency must be a three-letter uppercase code for invoice {}",
                    invoice_display_number(invoice)
                ));
            }
            if let Some(client_id) = &invoice.client_id {
                if !self.clients.iter().any(|client| &client.id == client_id) {
                    issues.push(format!(
                        "Invoice references a missing client: {}",
                        invoice_display_number(invoice)
                    ));
                }
            }
            if let Some(project_id) = &invoice.project_id {
                if !self
                    .projects
                    .iter()
                    .any(|project| &project.id == project_id)
                {
                    issues.push(format!(
                        "Invoice references a missing project: {}",
                        invoice_display_number(invoice)
                    ));
                }
            }
            for payment_detail_id in &invoice.accepted_payment_detail_ids {
                if !self
                    .payment_acceptance_details
                    .iter()
                    .any(|detail| &detail.id == payment_detail_id)
                {
                    issues.push(format!(
                        "Invoice references missing payment details: {}",
                        invoice_display_number(invoice)
                    ));
                }
            }
            if invoice.paid_minor_units() > invoice.total_minor_units() {
                issues.push(format!(
                    "Payments cannot exceed invoice total for invoice {}",
                    invoice_display_number(invoice)
                ));
            }
            for payment in &invoice.payments {
                if payment.amount_minor_units <= 0 {
                    issues.push(format!(
                        "Payment amount must be greater than zero for invoice {}",
                        invoice_display_number(invoice)
                    ));
                }
            }
            for item in &invoice.line_items {
                let item_label = if item.title.trim().is_empty() {
                    "line item"
                } else {
                    item.title.as_str()
                };
                if item.title.trim().is_empty() {
                    issues.push(format!(
                        "Line item title is required for invoice {}",
                        invoice_display_number(invoice)
                    ));
                }
                if item.quantity <= 0.0 || !item.quantity.is_finite() {
                    issues.push(format!(
                        "Line item quantity must be greater than zero for {item_label}"
                    ));
                }
                if item.unit_price_minor_units < 0 {
                    issues.push(format!(
                        "Line item unit price cannot be negative for {item_label}"
                    ));
                }
                if item.tax_rate_percent < 0.0
                    || item.tax_rate_percent > 100.0
                    || !item.tax_rate_percent.is_finite()
                {
                    issues.push(format!(
                        "Line item tax rate must be between 0 and 100 for {item_label}"
                    ));
                }
            }
        }

        if issues.is_empty() {
            Ok(())
        } else {
            Err(format!(
                "error: validation_failed\nmessage: {}\nhint: Fix invalid invoice data before saving.\n",
                issues.join("; ")
            ))
        }
    }

    pub fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "store root must be a JSON object".to_string())?;
        Ok(Self {
            schema_version: get_i64(object, "schemaVersion").unwrap_or(CURRENT_SCHEMA_VERSION),
            business_profile: object
                .get("businessProfile")
                .map(BusinessProfile::from_json)
                .transpose()?
                .unwrap_or_default(),
            clients: get_array(object, "clients")
                .unwrap_or(&[])
                .iter()
                .map(Client::from_json)
                .collect::<Result<_, _>>()?,
            projects: get_array(object, "projects")
                .unwrap_or(&[])
                .iter()
                .map(Project::from_json)
                .collect::<Result<_, _>>()?,
            payment_acceptance_details: get_array(object, "paymentAcceptanceDetails")
                .unwrap_or(&[])
                .iter()
                .map(PaymentAcceptanceDetail::from_json)
                .collect::<Result<_, _>>()?,
            invoices: get_array(object, "invoices")
                .unwrap_or(&[])
                .iter()
                .map(Invoice::from_json)
                .collect::<Result<_, _>>()?,
        })
    }

    pub fn to_json(&self) -> JsonValue {
        json::object([
            (
                "businessProfile".to_string(),
                self.business_profile.to_json(),
            ),
            (
                "clients".to_string(),
                JsonValue::Array(self.clients.iter().map(Client::to_json).collect()),
            ),
            (
                "invoices".to_string(),
                JsonValue::Array(self.invoices.iter().map(Invoice::to_json).collect()),
            ),
            (
                "paymentAcceptanceDetails".to_string(),
                JsonValue::Array(
                    self.payment_acceptance_details
                        .iter()
                        .map(PaymentAcceptanceDetail::to_json)
                        .collect(),
                ),
            ),
            (
                "projects".to_string(),
                JsonValue::Array(self.projects.iter().map(Project::to_json).collect()),
            ),
            (
                "schemaVersion".to_string(),
                json::number(CURRENT_SCHEMA_VERSION),
            ),
        ])
    }
}

fn automatic_invoice_copy(
    source_invoice: &Invoice,
    number: String,
    issue_date: &str,
    now: &str,
) -> Invoice {
    let due_offset_seconds =
        seconds_between_iso(&source_invoice.issue_date, &source_invoice.due_date)
            .unwrap_or(0)
            .max(0);

    Invoice {
        id: new_id(),
        number,
        client_id: source_invoice.client_id.clone(),
        project_id: source_invoice.project_id.clone(),
        issue_date: issue_date.to_string(),
        due_date: add_seconds_iso(issue_date, due_offset_seconds),
        status: InvoiceStatus::Draft,
        currency_code: source_invoice.currency_code.clone(),
        line_items: source_invoice
            .line_items
            .iter()
            .map(|item| InvoiceLineItem {
                id: new_id(),
                title: item.title.clone(),
                details: item.details.clone(),
                quantity: item.quantity,
                unit_price_minor_units: item.unit_price_minor_units,
                tax_rate_percent: item.tax_rate_percent,
            })
            .collect(),
        payments: Vec::new(),
        notes: source_invoice.notes.clone(),
        terms: source_invoice.terms.clone(),
        accepted_payment_detail_ids: source_invoice.accepted_payment_detail_ids.clone(),
        auto_generation: InvoiceAutoGenerationSettings::disabled(),
        created_at: now.to_string(),
        updated_at: now.to_string(),
    }
}

fn invoice_display_number(invoice: &Invoice) -> String {
    let trimmed = invoice.number.trim();
    if trimmed.is_empty() {
        invoice.id.clone()
    } else {
        trimmed.to_string()
    }
}

fn is_valid_currency_code(value: &str) -> bool {
    value.len() == 3 && value.bytes().all(|byte| byte.is_ascii_uppercase())
}

impl BusinessProfile {
    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "businessProfile must be an object".to_string())?;
        let default = BusinessProfile::default();
        Ok(Self {
            name: get_string(object, "name").unwrap_or(default.name),
            email: get_string(object, "email").unwrap_or(default.email),
            address: get_string(object, "address").unwrap_or(default.address),
            tax_identifier: get_string(object, "taxIdentifier").unwrap_or(default.tax_identifier),
            currency_code: get_string(object, "currencyCode").unwrap_or(default.currency_code),
            payment_terms_days: get_i64(object, "paymentTermsDays")
                .unwrap_or(default.payment_terms_days),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            ("address".to_string(), json::string(&self.address)),
            (
                "currencyCode".to_string(),
                json::string(&self.currency_code),
            ),
            ("email".to_string(), json::string(&self.email)),
            ("name".to_string(), json::string(&self.name)),
            (
                "paymentTermsDays".to_string(),
                json::number(self.payment_terms_days),
            ),
            (
                "taxIdentifier".to_string(),
                json::string(&self.tax_identifier),
            ),
        ])
    }
}

impl Client {
    pub fn new(name: String, now: &str) -> Self {
        Self {
            id: new_id(),
            name,
            company: String::new(),
            email: String::new(),
            address: String::new(),
            notes: String::new(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "client must be an object".to_string())?;
        let now = now_iso();
        Ok(Self {
            id: required_string(object, "id")?,
            name: get_string(object, "name").unwrap_or_default(),
            company: get_string(object, "company").unwrap_or_default(),
            email: get_string(object, "email").unwrap_or_default(),
            address: get_string(object, "address").unwrap_or_default(),
            notes: get_string(object, "notes").unwrap_or_default(),
            created_at: get_string(object, "createdAt").unwrap_or_else(|| now.clone()),
            updated_at: get_string(object, "updatedAt").unwrap_or(now),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            ("address".to_string(), json::string(&self.address)),
            ("company".to_string(), json::string(&self.company)),
            ("createdAt".to_string(), json::string(&self.created_at)),
            ("email".to_string(), json::string(&self.email)),
            ("id".to_string(), json::string(&self.id)),
            ("name".to_string(), json::string(&self.name)),
            ("notes".to_string(), json::string(&self.notes)),
            ("updatedAt".to_string(), json::string(&self.updated_at)),
        ])
    }
}

impl Project {
    pub fn new(name: String, currency_code: String, now: &str) -> Self {
        Self {
            id: new_id(),
            client_id: None,
            name,
            summary: String::new(),
            hourly_rate_minor_units: 0,
            currency_code,
            created_at: now.to_string(),
            updated_at: now.to_string(),
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "project must be an object".to_string())?;
        let now = now_iso();
        Ok(Self {
            id: required_string(object, "id")?,
            client_id: get_optional_string(object, "clientId"),
            name: get_string(object, "name").unwrap_or_default(),
            summary: get_string(object, "summary").unwrap_or_default(),
            hourly_rate_minor_units: get_i64(object, "hourlyRateMinorUnits").unwrap_or(0),
            currency_code: get_string(object, "currencyCode").unwrap_or_else(|| "USD".to_string()),
            created_at: get_string(object, "createdAt").unwrap_or_else(|| now.clone()),
            updated_at: get_string(object, "updatedAt").unwrap_or(now),
        })
    }

    fn to_json(&self) -> JsonValue {
        let mut entries = BTreeMap::new();
        if let Some(client_id) = &self.client_id {
            entries.insert("clientId".to_string(), json::string(client_id));
        }
        entries.insert("createdAt".to_string(), json::string(&self.created_at));
        entries.insert(
            "currencyCode".to_string(),
            json::string(&self.currency_code),
        );
        entries.insert(
            "hourlyRateMinorUnits".to_string(),
            json::number(self.hourly_rate_minor_units),
        );
        entries.insert("id".to_string(), json::string(&self.id));
        entries.insert("name".to_string(), json::string(&self.name));
        entries.insert("summary".to_string(), json::string(&self.summary));
        entries.insert("updatedAt".to_string(), json::string(&self.updated_at));
        JsonValue::Object(entries)
    }
}

impl InvoiceLineItem {
    pub fn new(title: String, unit_price_minor_units: i64) -> Self {
        Self {
            id: new_id(),
            title,
            details: String::new(),
            quantity: 1.0,
            unit_price_minor_units,
            tax_rate_percent: 0.0,
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "line item must be an object".to_string())?;
        Ok(Self {
            id: required_string(object, "id")?,
            title: get_string(object, "title").unwrap_or_default(),
            details: get_string(object, "details").unwrap_or_default(),
            quantity: get_f64(object, "quantity").unwrap_or(1.0),
            unit_price_minor_units: get_i64(object, "unitPriceMinorUnits").unwrap_or(0),
            tax_rate_percent: get_f64(object, "taxRatePercent").unwrap_or(0.0),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            ("details".to_string(), json::string(&self.details)),
            ("id".to_string(), json::string(&self.id)),
            (
                "quantity".to_string(),
                json::number(format_float(self.quantity)),
            ),
            (
                "taxRatePercent".to_string(),
                json::number(format_float(self.tax_rate_percent)),
            ),
            ("title".to_string(), json::string(&self.title)),
            (
                "unitPriceMinorUnits".to_string(),
                json::number(self.unit_price_minor_units),
            ),
        ])
    }
}

impl PaymentAcceptanceDetail {
    pub fn new(kind: PaymentAcceptanceKind, now: &str) -> Self {
        let label = match kind {
            PaymentAcceptanceKind::BankDetails => "Bank account",
            PaymentAcceptanceKind::Cryptocurrency => "Crypto wallet",
        };
        Self {
            id: new_id(),
            kind,
            label: label.to_string(),
            details: String::new(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "payment acceptance detail must be an object".to_string())?;
        let now = now_iso();
        Ok(Self {
            id: required_string(object, "id")?,
            kind: PaymentAcceptanceKind::parse(
                &get_string(object, "kind").unwrap_or_else(|| "bankDetails".to_string()),
            )?,
            label: get_string(object, "label").unwrap_or_default(),
            details: get_string(object, "details").unwrap_or_default(),
            created_at: get_string(object, "createdAt").unwrap_or_else(|| now.clone()),
            updated_at: get_string(object, "updatedAt").unwrap_or(now),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            ("createdAt".to_string(), json::string(&self.created_at)),
            ("details".to_string(), json::string(&self.details)),
            ("id".to_string(), json::string(&self.id)),
            ("kind".to_string(), json::string(self.kind.raw_value())),
            ("label".to_string(), json::string(&self.label)),
            ("updatedAt".to_string(), json::string(&self.updated_at)),
        ])
    }
}

impl Payment {
    pub fn new(amount_minor_units: i64, now: &str) -> Self {
        Self {
            id: new_id(),
            amount_minor_units,
            paid_at: now.to_string(),
            reference: String::new(),
            notes: String::new(),
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "payment must be an object".to_string())?;
        Ok(Self {
            id: required_string(object, "id")?,
            amount_minor_units: get_i64(object, "amountMinorUnits").unwrap_or(0),
            paid_at: get_string(object, "paidAt").unwrap_or_else(now_iso),
            reference: get_string(object, "reference").unwrap_or_default(),
            notes: get_string(object, "notes").unwrap_or_default(),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            (
                "amountMinorUnits".to_string(),
                json::number(self.amount_minor_units),
            ),
            ("id".to_string(), json::string(&self.id)),
            ("notes".to_string(), json::string(&self.notes)),
            ("paidAt".to_string(), json::string(&self.paid_at)),
            ("reference".to_string(), json::string(&self.reference)),
        ])
    }
}

impl InvoiceAutoGenerationSettings {
    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "autoGeneration must be an object".to_string())?;
        let interval_days = if let Some(interval_days) = get_i64(object, "intervalDays") {
            Self::normalized_interval_days(interval_days)
        } else if let Some(interval_seconds) = get_i64(object, "intervalSeconds") {
            Self::interval_days_from_legacy_seconds(interval_seconds)
        } else {
            30
        };

        Ok(Self {
            is_enabled: get_bool(object, "isEnabled").unwrap_or(false),
            interval_days,
            next_generation_date: get_string(object, "nextGenerationDate")
                .unwrap_or_else(|| "1970-01-01T00:00:00Z".to_string()),
        })
    }

    fn to_json(&self) -> JsonValue {
        json::object([
            ("intervalDays".to_string(), json::number(self.interval_days)),
            ("isEnabled".to_string(), JsonValue::Bool(self.is_enabled)),
            (
                "nextGenerationDate".to_string(),
                json::string(&self.next_generation_date),
            ),
        ])
    }

    fn interval_days_from_legacy_seconds(value: i64) -> i64 {
        let normalized_seconds = value.clamp(1, Self::MAXIMUM_INTERVAL_DAYS * 86_400);
        let days = (normalized_seconds + 86_399) / 86_400;
        Self::normalized_interval_days(days)
    }
}

impl Invoice {
    pub fn new(number: String, due_date: String, now: &str) -> Self {
        Self {
            id: new_id(),
            number,
            client_id: None,
            project_id: None,
            issue_date: now.to_string(),
            due_date,
            status: InvoiceStatus::Draft,
            currency_code: "USD".to_string(),
            line_items: Vec::new(),
            payments: Vec::new(),
            notes: String::new(),
            terms: "Payment due on receipt.".to_string(),
            accepted_payment_detail_ids: Vec::new(),
            auto_generation: InvoiceAutoGenerationSettings::disabled(),
            created_at: now.to_string(),
            updated_at: now.to_string(),
        }
    }

    fn from_json(value: &JsonValue) -> Result<Self, String> {
        let object = value
            .as_object()
            .ok_or_else(|| "invoice must be an object".to_string())?;
        let issue_date = required_string(object, "issueDate")?;
        let created_at = get_string(object, "createdAt").unwrap_or_else(|| issue_date.clone());
        Ok(Self {
            id: required_string(object, "id")?,
            number: required_string(object, "number")?,
            client_id: get_optional_string(object, "clientId"),
            project_id: get_optional_string(object, "projectId"),
            issue_date,
            due_date: required_string(object, "dueDate")?,
            status: InvoiceStatus::parse(
                &get_string(object, "status").unwrap_or_else(|| "draft".to_string()),
            )?,
            currency_code: get_string(object, "currencyCode").unwrap_or_else(|| "USD".to_string()),
            line_items: get_array(object, "lineItems")
                .unwrap_or(&[])
                .iter()
                .map(InvoiceLineItem::from_json)
                .collect::<Result<_, _>>()?,
            payments: get_array(object, "payments")
                .unwrap_or(&[])
                .iter()
                .map(Payment::from_json)
                .collect::<Result<_, _>>()?,
            notes: get_string(object, "notes").unwrap_or_default(),
            terms: get_string(object, "terms")
                .unwrap_or_else(|| "Payment due on receipt.".to_string()),
            accepted_payment_detail_ids: get_array(object, "acceptedPaymentDetailIDs")
                .unwrap_or(&[])
                .iter()
                .filter_map(JsonValue::as_str)
                .map(str::to_string)
                .collect(),
            auto_generation: object
                .get("autoGeneration")
                .map(InvoiceAutoGenerationSettings::from_json)
                .transpose()?
                .unwrap_or_else(InvoiceAutoGenerationSettings::disabled),
            updated_at: get_string(object, "updatedAt").unwrap_or_else(|| created_at.clone()),
            created_at,
        })
    }

    fn to_json(&self) -> JsonValue {
        let mut entries = BTreeMap::new();
        entries.insert(
            "acceptedPaymentDetailIDs".to_string(),
            JsonValue::Array(
                self.accepted_payment_detail_ids
                    .iter()
                    .map(json::string)
                    .collect(),
            ),
        );
        entries.insert("autoGeneration".to_string(), self.auto_generation.to_json());
        if let Some(client_id) = &self.client_id {
            entries.insert("clientId".to_string(), json::string(client_id));
        }
        entries.insert("createdAt".to_string(), json::string(&self.created_at));
        entries.insert(
            "currencyCode".to_string(),
            json::string(&self.currency_code),
        );
        entries.insert("dueDate".to_string(), json::string(&self.due_date));
        entries.insert("id".to_string(), json::string(&self.id));
        entries.insert("issueDate".to_string(), json::string(&self.issue_date));
        entries.insert(
            "lineItems".to_string(),
            JsonValue::Array(
                self.line_items
                    .iter()
                    .map(InvoiceLineItem::to_json)
                    .collect(),
            ),
        );
        entries.insert("notes".to_string(), json::string(&self.notes));
        entries.insert("number".to_string(), json::string(&self.number));
        entries.insert(
            "payments".to_string(),
            JsonValue::Array(self.payments.iter().map(Payment::to_json).collect()),
        );
        if let Some(project_id) = &self.project_id {
            entries.insert("projectId".to_string(), json::string(project_id));
        }
        entries.insert("status".to_string(), json::string(self.status.raw_value()));
        entries.insert("terms".to_string(), json::string(&self.terms));
        entries.insert("updatedAt".to_string(), json::string(&self.updated_at));
        JsonValue::Object(entries)
    }
}

pub fn parse_minor_units(raw_value: &str) -> Result<i64, String> {
    let trimmed = raw_value.trim().replace(',', "");
    if trimmed.is_empty() {
        return Err(format!("Invalid amount: {raw_value}"));
    }
    let is_negative = trimmed.starts_with('-');
    let unsigned = if is_negative {
        &trimmed[1..]
    } else {
        trimmed.as_str()
    };
    let parts: Vec<&str> = unsigned.split('.').collect();
    if parts.len() > 2 || parts[0].is_empty() {
        return Err(format!("Invalid amount: {raw_value}"));
    }
    let major = parts[0]
        .parse::<i64>()
        .map_err(|_| format!("Invalid amount: {raw_value}"))?;
    if major < 0 {
        return Err(format!("Invalid amount: {raw_value}"));
    }
    let cents = if parts.len() == 2 {
        let fraction = parts[1];
        if fraction.len() > 2 || !fraction.chars().all(|ch| ch.is_ascii_digit()) {
            return Err(format!("Invalid amount: {raw_value}"));
        }
        let mut padded = fraction.to_string();
        while padded.len() < 2 {
            padded.push('0');
        }
        padded.parse::<i64>().unwrap_or(0)
    } else {
        0
    };
    let result = major * 100 + cents;
    Ok(if is_negative { -result } else { result })
}

pub fn format_money(minor_units: i64, currency_code: &str) -> String {
    let sign = if minor_units < 0 { "-" } else { "" };
    let absolute = minor_units.abs();
    let major = absolute / 100;
    let cents = absolute % 100;
    format!("{currency_code} {sign}{major}.{cents:02}")
}

pub fn render_invoice_text(invoice: &Invoice, book: &InvoiceBook) -> String {
    let client = book.client_for(invoice);
    let project = book.project_for(invoice);
    let business = &book.business_profile;

    let mut lines = Vec::new();
    lines.push(format!("INVOICE {}", invoice.number));
    lines.push("=".repeat(72));
    lines.push(String::new());
    lines.push(format!("From: {}", business.name));
    if !business.email.is_empty() {
        lines.push(format!("Email: {}", business.email));
    }
    if !business.address.is_empty() {
        lines.push(business.address.clone());
    }
    if !business.tax_identifier.is_empty() {
        lines.push(format!("Tax ID: {}", business.tax_identifier));
    }
    lines.push(String::new());

    lines.push(format!(
        "Bill To: {}",
        client
            .map(|client| client.name.as_str())
            .unwrap_or("Unassigned client")
    ));
    if let Some(company) = client
        .map(|client| client.company.as_str())
        .filter(|value| !value.is_empty())
    {
        lines.push(company.to_string());
    }
    if let Some(email) = client
        .map(|client| client.email.as_str())
        .filter(|value| !value.is_empty())
    {
        lines.push(email.to_string());
    }
    if let Some(address) = client
        .map(|client| client.address.as_str())
        .filter(|value| !value.is_empty())
    {
        lines.push(address.to_string());
    }
    if let Some(project) = project.filter(|project| !project.name.is_empty()) {
        lines.push(format!("Project: {}", project.name));
    }
    lines.push(String::new());

    lines.push(format!(
        "Issue Date: {}",
        format_date_medium(&invoice.issue_date)
    ));
    lines.push(format!(
        "Due Date:   {}",
        format_date_medium(&invoice.due_date)
    ));
    lines.push(String::new());

    lines.push("Items".to_string());
    lines.push("-".repeat(72));
    for item in &invoice.line_items {
        let price = format_money(item.unit_price_minor_units, &invoice.currency_code);
        let total = format_money(item.total_minor_units(), &invoice.currency_code);
        lines.push(item.title.clone());
        if !item.details.is_empty() {
            lines.push(format!("  {}", item.details));
        }
        lines.push(format!(
            "  Qty {} x {}  Tax {}%  {}",
            trimmed_quantity(item.quantity),
            price,
            trimmed_quantity(item.tax_rate_percent),
            total
        ));
    }

    lines.push("-".repeat(72));
    lines.push(format!(
        "Subtotal: {}",
        format_money(invoice.subtotal_minor_units(), &invoice.currency_code)
    ));
    lines.push(format!(
        "Tax:      {}",
        format_money(invoice.tax_minor_units(), &invoice.currency_code)
    ));
    lines.push(format!(
        "Paid:     {}",
        format_money(invoice.paid_minor_units(), &invoice.currency_code)
    ));
    lines.push(format!(
        "Balance:  {}",
        format_money(invoice.balance_due_minor_units(), &invoice.currency_code)
    ));
    lines.push(String::new());

    if !invoice.notes.is_empty() {
        lines.push("Notes".to_string());
        lines.push(invoice.notes.clone());
        lines.push(String::new());
    }
    if !invoice.terms.is_empty() {
        lines.push("Terms".to_string());
        lines.push(invoice.terms.clone());
        lines.push(String::new());
    }

    let payment_details = book.payment_acceptance_details_for(invoice);
    if !payment_details.is_empty() {
        lines.push("Payment Acceptance".to_string());
        for detail in payment_details {
            lines.push(format!("{}: {}", detail.kind.label(), detail.label));
            for detail_line in detail
                .details
                .lines()
                .map(str::trim)
                .filter(|line| !line.is_empty())
            {
                lines.push(format!("  {detail_line}"));
            }
        }
        lines.push(String::new());
    }

    lines.join("\n")
}

pub fn render_invoice_pdf(invoice: &Invoice, book: &InvoiceBook) -> Vec<u8> {
    render_text_pdf(&render_invoice_text(invoice, book))
}

pub fn invoice_pdf_file_name(invoice: &Invoice) -> String {
    let mut file_stem = String::new();
    let mut previous_was_separator = false;

    for character in invoice.number.trim().chars() {
        if character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.') {
            file_stem.push(character);
            previous_was_separator = false;
        } else if !previous_was_separator {
            file_stem.push('-');
            previous_was_separator = true;
        }
    }

    let file_stem = file_stem.trim_matches(['-', '.', '_']);
    if file_stem.is_empty() {
        "invoice.pdf".to_string()
    } else {
        format!("{file_stem}.pdf")
    }
}

fn render_text_pdf(text: &str) -> Vec<u8> {
    const PAGE_WIDTH: i32 = 612;
    const PAGE_HEIGHT: i32 = 792;
    const LEFT_MARGIN: i32 = 50;
    const TOP_Y: i32 = 742;
    const LINE_HEIGHT: i32 = 14;
    const LINES_PER_PAGE: usize = 50;
    const MAX_LINE_CHARS: usize = 88;

    let mut lines = Vec::new();
    for line in text.lines() {
        lines.extend(wrap_pdf_line(line, MAX_LINE_CHARS));
    }
    if lines.is_empty() {
        lines.push(String::new());
    }

    let pages: Vec<&[String]> = lines.chunks(LINES_PER_PAGE).collect();
    let mut objects = Vec::new();

    objects.push("<< /Type /Catalog /Pages 2 0 R >>".to_string());

    let kids = pages
        .iter()
        .enumerate()
        .map(|(index, _)| format!("{} 0 R", 3 + index * 2))
        .collect::<Vec<_>>()
        .join(" ");
    objects.push(format!(
        "<< /Type /Pages /Kids [{kids}] /Count {} >>",
        pages.len()
    ));

    for (index, page_lines) in pages.iter().enumerate() {
        let page_id = 3 + index * 2;
        let content_id = page_id + 1;
        objects.push(format!(
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> /F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> >> >> /Contents {content_id} 0 R >>"
        ));

        let mut stream = format!("BT\n{LEFT_MARGIN} {TOP_Y} Td\n");
        for (line_index, line) in page_lines.iter().enumerate() {
            if is_pdf_heading(line, line_index) {
                let size = if line_index == 0 { 16 } else { 10 };
                stream.push_str(&format!("/F2 {size} Tf\n"));
            } else {
                stream.push_str("/F1 10 Tf\n");
            }
            if line_index > 0 {
                stream.push_str(&format!("0 -{LINE_HEIGHT} Td\n"));
            }
            stream.push('(');
            stream.push_str(&escape_pdf_literal(line));
            stream.push_str(") Tj\n");
        }
        stream.push_str("ET\n");

        objects.push(format!(
            "<< /Length {} >>\nstream\n{}endstream",
            stream.as_bytes().len(),
            stream
        ));
    }

    write_pdf_objects(objects)
}

fn is_pdf_heading(line: &str, line_index: usize) -> bool {
    line_index == 0
        || matches!(line, "Items" | "Notes" | "Terms" | "Payment Acceptance")
        || line.starts_with("Subtotal:")
        || line.starts_with("Balance:")
}

fn wrap_pdf_line(line: &str, max_chars: usize) -> Vec<String> {
    if line.is_empty() {
        return vec![String::new()];
    }

    let mut wrapped = Vec::new();
    let mut current = String::new();
    let mut count = 0;

    for character in line.chars() {
        if count == max_chars {
            wrapped.push(current);
            current = String::new();
            count = 0;
        }
        current.push(character);
        count += 1;
    }

    if !current.is_empty() {
        wrapped.push(current);
    }

    wrapped
}

fn escape_pdf_literal(value: &str) -> String {
    let mut escaped = String::new();
    for character in value.chars() {
        match character {
            '\\' => escaped.push_str("\\\\"),
            '(' => escaped.push_str("\\("),
            ')' => escaped.push_str("\\)"),
            '\t' => escaped.push_str("    "),
            character if character.is_control() => escaped.push(' '),
            character => escaped.push(character),
        }
    }
    escaped
}

fn write_pdf_objects(objects: Vec<String>) -> Vec<u8> {
    let mut pdf = Vec::new();
    pdf.extend_from_slice(b"%PDF-1.4\n");

    let mut offsets = Vec::with_capacity(objects.len() + 1);
    offsets.push(0);
    for (index, object) in objects.iter().enumerate() {
        offsets.push(pdf.len());
        pdf.extend_from_slice(format!("{} 0 obj\n", index + 1).as_bytes());
        pdf.extend_from_slice(object.as_bytes());
        pdf.extend_from_slice(b"\nendobj\n");
    }

    let xref_offset = pdf.len();
    pdf.extend_from_slice(format!("xref\n0 {}\n", offsets.len()).as_bytes());
    pdf.extend_from_slice(b"0000000000 65535 f \n");
    for offset in offsets.iter().skip(1) {
        pdf.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
    }
    pdf.extend_from_slice(
        format!(
            "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n",
            offsets.len()
        )
        .as_bytes(),
    );

    pdf
}

pub fn now_iso() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;
    iso_from_unix_seconds(seconds)
}

pub fn normalize_date_input(value: &str) -> Result<String, String> {
    let trimmed = value.trim();
    if trimmed.len() == 10 && parse_ymd(trimmed).is_some() {
        return Ok(format!("{trimmed}T00:00:00Z"));
    }
    if parse_iso_parts(trimmed).is_some() {
        return Ok(trimmed.to_string());
    }
    Err(format!("invalid date: {value}; use YYYY-MM-DD or ISO-8601"))
}

pub fn add_days_iso(value: &str, days: i64) -> String {
    if let Some((year, month, day, hour, minute, second)) = parse_iso_parts(value) {
        let shifted = days_from_civil(year, month, day) + days;
        let (year, month, day) = civil_from_days(shifted);
        format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}Z")
    } else {
        value.to_string()
    }
}

fn add_seconds_iso(value: &str, seconds: i64) -> String {
    unix_seconds_from_iso(value)
        .map(|base| iso_from_unix_seconds(base + seconds))
        .unwrap_or_else(|| value.to_string())
}

pub fn format_date_medium(value: &str) -> String {
    let Some((year, month, day)) = parse_ymd(value) else {
        return value.to_string();
    };
    let month_name = match month {
        1 => "Jan",
        2 => "Feb",
        3 => "Mar",
        4 => "Apr",
        5 => "May",
        6 => "Jun",
        7 => "Jul",
        8 => "Aug",
        9 => "Sep",
        10 => "Oct",
        11 => "Nov",
        12 => "Dec",
        _ => return value.to_string(),
    };
    format!("{month_name} {day}, {year}")
}

fn get_array<'a>(object: &'a BTreeMap<String, JsonValue>, key: &str) -> Option<&'a [JsonValue]> {
    object.get(key).and_then(JsonValue::as_array)
}

fn get_i64(object: &BTreeMap<String, JsonValue>, key: &str) -> Option<i64> {
    object.get(key).and_then(JsonValue::as_i64)
}

fn get_bool(object: &BTreeMap<String, JsonValue>, key: &str) -> Option<bool> {
    match object.get(key) {
        Some(JsonValue::Bool(value)) => Some(*value),
        _ => None,
    }
}

fn get_f64(object: &BTreeMap<String, JsonValue>, key: &str) -> Option<f64> {
    object.get(key).and_then(JsonValue::as_f64)
}

fn get_string(object: &BTreeMap<String, JsonValue>, key: &str) -> Option<String> {
    object
        .get(key)
        .and_then(JsonValue::as_str)
        .map(str::to_string)
}

fn get_optional_string(object: &BTreeMap<String, JsonValue>, key: &str) -> Option<String> {
    match object.get(key) {
        Some(JsonValue::String(value)) if !value.is_empty() => Some(value.clone()),
        _ => None,
    }
}

fn required_string(object: &BTreeMap<String, JsonValue>, key: &str) -> Result<String, String> {
    get_string(object, key).ok_or_else(|| format!("missing required string field: {key}"))
}

fn format_float(value: f64) -> String {
    if value.fract() == 0.0 {
        format!("{value:.0}")
    } else {
        let mut rendered = format!("{value}");
        if rendered.contains('.') {
            while rendered.ends_with('0') {
                rendered.pop();
            }
            if rendered.ends_with('.') {
                rendered.push('0');
            }
        }
        rendered
    }
}

fn trimmed_quantity(value: f64) -> String {
    if value.round() == value {
        format!("{value:.0}")
    } else {
        format!("{value:.2}")
    }
}

fn new_id() -> String {
    let mut bytes = [0_u8; 16];
    if File::open("/dev/urandom")
        .and_then(|mut file| file.read_exact(&mut bytes))
        .is_err()
    {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let count = u128::from(ID_COUNTER.fetch_add(1, Ordering::Relaxed));
        bytes = (now ^ count).to_be_bytes();
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    format!(
        "{:02x}{:02x}{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}{:02x}{:02x}{:02x}{:02x}",
        bytes[0],
        bytes[1],
        bytes[2],
        bytes[3],
        bytes[4],
        bytes[5],
        bytes[6],
        bytes[7],
        bytes[8],
        bytes[9],
        bytes[10],
        bytes[11],
        bytes[12],
        bytes[13],
        bytes[14],
        bytes[15]
    )
}

fn year_from_date(value: &str) -> Option<i32> {
    parse_ymd(value).map(|(year, _, _)| year)
}

fn date_before(left: &str, right: &str) -> bool {
    match (parse_iso_parts(left), parse_iso_parts(right)) {
        (Some(left), Some(right)) => left < right,
        _ => left < right,
    }
}

fn seconds_between_iso(start: &str, end: &str) -> Option<i64> {
    Some(unix_seconds_from_iso(end)? - unix_seconds_from_iso(start)?)
}

fn unix_seconds_from_iso(value: &str) -> Option<i64> {
    let (year, month, day, hour, minute, second) = parse_iso_parts(value)?;
    Some(
        days_from_civil(year, month, day) * 86_400
            + i64::from(hour) * 3_600
            + i64::from(minute) * 60
            + i64::from(second),
    )
}

fn parse_iso_parts(value: &str) -> Option<(i32, u32, u32, u32, u32, u32)> {
    let (year, month, day) = parse_ymd(value)?;
    let time = value.get(11..19).unwrap_or("00:00:00");
    let hour = time.get(0..2)?.parse().ok()?;
    let minute = time.get(3..5)?.parse().ok()?;
    let second = time.get(6..8)?.parse().ok()?;
    Some((year, month, day, hour, minute, second))
}

fn parse_ymd(value: &str) -> Option<(i32, u32, u32)> {
    let date = value.get(0..10)?;
    if date.as_bytes().get(4) != Some(&b'-') || date.as_bytes().get(7) != Some(&b'-') {
        return None;
    }
    let year = date.get(0..4)?.parse().ok()?;
    let month = date.get(5..7)?.parse().ok()?;
    let day = date.get(8..10)?.parse().ok()?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    Some((year, month, day))
}

fn iso_from_unix_seconds(seconds: i64) -> String {
    let days = seconds.div_euclid(86_400);
    let seconds_of_day = seconds.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);
    let hour = seconds_of_day / 3_600;
    let minute = (seconds_of_day % 3_600) / 60;
    let second = seconds_of_day % 60;
    format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}Z")
}

fn days_from_civil(year: i32, month: u32, day: u32) -> i64 {
    let year = i64::from(year) - if month <= 2 { 1 } else { 0 };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let yoe = year - era * 400;
    let month = i64::from(month);
    let day = i64::from(day);
    let doy = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(days: i64) -> (i32, u32, u32) {
    let days = days + 719_468;
    let era = if days >= 0 { days } else { days - 146_096 } / 146_097;
    let doe = days - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = mp + if mp < 10 { 3 } else { -9 };
    let year = year + if month <= 2 { 1 } else { 0 };
    (year as i32, month as u32, day as u32)
}
