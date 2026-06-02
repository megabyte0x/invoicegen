use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::time::{SystemTime, UNIX_EPOCH};

fn bin() -> &'static str {
    env!("CARGO_BIN_EXE_invoicegen-rs")
}

fn temp_store(label: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "invoicegen-rs-{label}-{}-{nanos}/store.json",
        std::process::id()
    ))
}

fn run(store: &Path, args: &[&str]) -> Output {
    Command::new(bin())
        .arg("--store")
        .arg(store)
        .args(args)
        .output()
        .expect("failed to run invoicegen-rs")
}

fn run_without_store(args: &[&str]) -> Output {
    Command::new(bin())
        .args(args)
        .output()
        .expect("failed to run invoicegen-rs")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).into_owned()
}

fn assert_success(output: Output) -> String {
    assert!(
        output.status.success(),
        "expected success\nstdout:\n{}\nstderr:\n{}",
        stdout(&output),
        stderr(&output)
    );
    stdout(&output)
}

fn assert_failure(output: Output) -> String {
    assert!(
        !output.status.success(),
        "expected failure\nstdout:\n{}\nstderr:\n{}",
        stdout(&output),
        stderr(&output)
    );
    stderr(&output)
}

fn id_from_created_line(output: &str, entity: &str) -> String {
    let prefix = format!("Created {entity} ");
    output
        .lines()
        .find_map(|line| line.strip_prefix(&prefix))
        .unwrap_or_else(|| panic!("missing line with prefix {prefix:?} in:\n{output}"))
        .trim()
        .to_string()
}

#[test]
fn cli_exposes_command_help_examples_and_shell_completions() {
    let global_help = assert_success(run_without_store(&["--help"]));
    assert!(global_help.contains("Examples:"), "{global_help}");
    assert!(
        global_help.contains("invoicegen-rs --store /tmp/invoicegen-store.json invoice list"),
        "{global_help}"
    );

    let invoice_help = assert_success(run_without_store(&["invoice", "--help"]));
    assert!(invoice_help.contains("Usage:"), "{invoice_help}");
    assert!(
        invoice_help.contains("invoicegen-rs invoice list [--status STATUS]"),
        "{invoice_help}"
    );
    assert!(invoice_help.contains("Examples:"), "{invoice_help}");

    let client_help = assert_success(run_without_store(&["client", "--help"]));
    assert!(client_help.contains("Examples:"), "{client_help}");
    assert!(
        client_help.contains("invoicegen-rs client list --query acme --format csv"),
        "{client_help}"
    );

    let completion = assert_success(run_without_store(&["completion", "zsh"]));
    assert!(
        completion.contains("#compdef invoicegen-rs"),
        "{completion}"
    );
    assert!(completion.contains("invoice"), "{completion}");
    assert!(completion.contains("client"), "{completion}");
}

#[test]
fn cli_outputs_json_csv_tsv_and_filters_lists() {
    let store = temp_store("format-filter");
    assert_success(run(&store, &["seed-sample", "--force"]));

    let overdue_json = assert_success(run(
        &store,
        &["invoice", "list", "--status", "overdue", "--format", "json"],
    ));
    assert!(overdue_json.trim_start().starts_with('['), "{overdue_json}");
    assert!(
        overdue_json.contains(r#""status": "overdue""#),
        "{overdue_json}"
    );
    assert!(
        !overdue_json.contains(r#""status": "sent""#),
        "{overdue_json}"
    );

    let client_csv = assert_success(run(
        &store,
        &["client", "list", "--query", "avery", "--format", "csv"],
    ));
    assert!(
        client_csv.starts_with("id,name,email,company\n"),
        "{client_csv}"
    );
    assert!(client_csv.contains("Avery Patel"), "{client_csv}");
    assert!(!client_csv.contains("Northstar Studio"), "{client_csv}");

    let project_tsv = assert_success(run(&store, &["project", "list", "--format", "tsv"]));
    assert!(
        project_tsv.starts_with("id\tname\tclient\trate\n"),
        "{project_tsv}"
    );

    let summary_json = assert_success(run(&store, &["summary", "--format", "json"]));
    assert!(summary_json.trim_start().starts_with('{'), "{summary_json}");
    assert!(summary_json.contains(r#""outstanding""#), "{summary_json}");
}

#[test]
fn cli_uses_config_for_store_and_default_output() {
    let store = temp_store("configured-store");
    let config = temp_store("configured-store").with_file_name("invoicegen-config.json");
    let store_text = store.to_string_lossy().into_owned();
    let config_text = config.to_string_lossy().into_owned();

    assert_success(run_without_store(&[
        "--config",
        &config_text,
        "config",
        "set",
        "--store",
        &store_text,
        "--default-output",
        "json",
    ]));
    assert_success(run_without_store(&[
        "--config",
        &config_text,
        "seed-sample",
        "--force",
    ]));

    let clients = assert_success(run_without_store(&[
        "--config",
        &config_text,
        "client",
        "list",
    ]));
    assert!(clients.trim_start().starts_with('['), "{clients}");
    assert!(clients.contains(r#""name": "Avery Patel""#), "{clients}");
    assert!(store.exists(), "configured store was not written");

    let shown = assert_success(run_without_store(&[
        "--config",
        &config_text,
        "config",
        "show",
        "--format",
        "json",
    ]));
    assert!(shown.contains(r#""defaultOutput": "json""#), "{shown}");
    assert!(shown.contains(&store_text), "{shown}");
}

#[test]
fn destructive_commands_require_force_and_errors_are_actionable() {
    let store = temp_store("force-errors");
    let client_id = id_from_created_line(
        &assert_success(run(&store, &["client", "add", "--name", "Delete Me"])),
        "client",
    );

    let stderr = assert_failure(run(&store, &["client", "delete", &client_id]));
    assert!(
        stderr.contains("error: destructive_action_requires_force"),
        "{stderr}"
    );
    assert!(stderr.contains("hint: pass --force"), "{stderr}");

    assert_success(run(&store, &["client", "delete", &client_id, "--force"]));

    let missing_value = assert_failure(run(&store, &["client", "add", "--name"]));
    assert!(
        missing_value.contains("error: missing_value"),
        "{missing_value}"
    );
    assert!(
        missing_value.contains("--name requires a value"),
        "{missing_value}"
    );

    let unknown = assert_failure(run_without_store(&["bogus"]));
    assert!(unknown.contains("error: unknown_command"), "{unknown}");
    assert!(
        unknown.contains("hint: run invoicegen-rs --help"),
        "{unknown}"
    );
}

#[test]
fn money_contract_matches_swift_core() {
    assert_eq!(
        invoicegen_rs::parse_minor_units("1,234.50").unwrap(),
        123_450
    );
    assert_eq!(invoicegen_rs::parse_minor_units("-12.3").unwrap(), -1_230);
    assert_eq!(invoicegen_rs::format_money(123_450, "USD"), "USD 1234.50");
    assert_eq!(invoicegen_rs::format_money(-1_230, "EUR"), "EUR -12.30");
    assert!(invoicegen_rs::parse_minor_units("12.345").is_err());
    assert!(invoicegen_rs::parse_minor_units("").is_err());
}

#[test]
fn default_store_paths_are_platform_appropriate_for_packaged_cli() {
    assert_eq!(
        invoicegen_rs::default_store_path_for_environment(
            "windows",
            &[
                ("APPDATA", r"C:\Users\Ada\AppData\Roaming"),
                ("HOME", r"C:\Users\Ada")
            ]
        ),
        PathBuf::from(r"C:\Users\Ada\AppData\Roaming")
            .join("InvoiceGen")
            .join("store.json")
    );
    assert_eq!(
        invoicegen_rs::default_store_path_for_environment(
            "linux",
            &[
                ("XDG_DATA_HOME", "/home/ada/.local/state"),
                ("HOME", "/home/ada")
            ]
        ),
        PathBuf::from("/home/ada/.local/state")
            .join("invoicegen-app")
            .join("store.json")
    );
    assert_eq!(
        invoicegen_rs::default_store_path_for_environment("macos", &[("HOME", "/Users/ada")]),
        PathBuf::from("/Users/ada")
            .join("Library")
            .join("Application Support")
            .join("InvoiceGen")
            .join("store.json")
    );
    assert_eq!(
        invoicegen_rs::default_store_path_for_environment(
            "linux",
            &[
                ("INVOICEGEN_APP_STORE", "~/custom/invoices.json"),
                ("HOME", "/home/ada")
            ]
        ),
        PathBuf::from("/home/ada/custom/invoices.json")
    );
}

#[test]
fn cli_creates_entities_persists_swift_compatible_json_and_renders_invoice_text() {
    let store = temp_store("crud-render");

    assert_success(run(
        &store,
        &[
            "profile",
            "set",
            "--name",
            "Test Studio",
            "--email",
            "billing@test.example",
            "--address",
            "1 Local Road\nTest City",
            "--tax-id",
            "TAX-123",
            "--currency",
            "USD",
            "--terms-days",
            "7",
        ],
    ));

    let client_id = id_from_created_line(
        &assert_success(run(
            &store,
            &[
                "client",
                "add",
                "--name",
                "Ada Lovelace",
                "--company",
                "Analytical Engines LLC",
                "--email",
                "ada@example.com",
                "--address",
                "42 Byron Street",
                "--notes",
                "Prefers itemized invoices",
            ],
        )),
        "client",
    );

    let project_id = id_from_created_line(
        &assert_success(run(
            &store,
            &[
                "project",
                "add",
                "--name",
                "Launch",
                "--client",
                &client_id,
                "--summary",
                "Go-to-market launch",
                "--rate",
                "125.00",
            ],
        )),
        "project",
    );

    let payment_id = id_from_created_line(
        &assert_success(run(
            &store,
            &[
                "payment-detail",
                "add",
                "--kind",
                "bank-details",
                "--label",
                "Primary bank account",
                "--detail",
                "Account: 123456789",
                "--detail",
                "Routing: 987654321",
            ],
        )),
        "payment detail",
    );

    let invoice_id = id_from_created_line(
        &assert_success(run(
            &store,
            &[
                "invoice",
                "add",
                "--number",
                "INV-TEST-0001",
                "--client",
                &client_id,
                "--project",
                &project_id,
                "--issue-date",
                "2026-01-01",
                "--due-date",
                "2026-01-08",
                "--currency",
                "USD",
                "--terms",
                "Net 7.",
            ],
        )),
        "invoice",
    );

    assert_success(run(
        &store,
        &[
            "invoice",
            "add-item",
            &invoice_id,
            "--title",
            "Design implementation",
            "--details",
            "Landing page and invoice workflow",
            "--quantity",
            "2",
            "--unit-price",
            "100.00",
            "--tax-rate",
            "10",
        ],
    ));
    assert_success(run(
        &store,
        &["invoice", "accept-payment", &invoice_id, &payment_id],
    ));

    let rendered = assert_success(run(&store, &["invoice", "render", &invoice_id]));
    assert!(rendered.contains("INVOICE INV-TEST-0001"), "{rendered}");
    assert!(rendered.contains("From: Test Studio"), "{rendered}");
    assert!(rendered.contains("Bill To: Ada Lovelace"), "{rendered}");
    assert!(rendered.contains("Project: Launch"), "{rendered}");
    assert!(
        rendered.contains("Qty 2 x USD 100.00  Tax 10%  USD 220.00"),
        "{rendered}"
    );
    assert!(rendered.contains("Subtotal: USD 200.00"), "{rendered}");
    assert!(rendered.contains("Tax:      USD 20.00"), "{rendered}");
    assert!(rendered.contains("Balance:  USD 220.00"), "{rendered}");
    assert!(rendered.contains("Payment Acceptance"), "{rendered}");
    assert!(
        rendered.contains("Bank Details: Primary bank account"),
        "{rendered}"
    );
    assert!(rendered.contains("Account: 123456789"), "{rendered}");
    assert!(!rendered.contains("Status:"), "{rendered}");

    let output_directory = store.with_file_name("exports");
    fs::create_dir_all(&output_directory).unwrap();
    let pdf_path = output_directory.join("INV-TEST-0001.pdf");
    let output_directory_text = output_directory.to_string_lossy().into_owned();
    let pdf_path_text = pdf_path.to_string_lossy().into_owned();
    let wrote_pdf = assert_success(run(
        &store,
        &[
            "invoice",
            "render",
            &invoice_id,
            "--output",
            &output_directory_text,
        ],
    ));
    assert!(
        wrote_pdf.contains(&format!("Wrote {pdf_path_text}")),
        "{wrote_pdf}"
    );
    let pdf_bytes = fs::read(&pdf_path).unwrap();
    assert!(pdf_bytes.starts_with(b"%PDF-"), "{pdf_bytes:?}");
    let pdf_text = String::from_utf8_lossy(&pdf_bytes);
    assert!(pdf_text.contains("INVOICE INV-TEST-0001"), "{pdf_text}");
    assert!(!pdf_text.contains("Status:"), "{pdf_text}");

    assert_success(run(&store, &["invoice", "mark-paid", &invoice_id]));
    let paid_rendered = assert_success(run(&store, &["invoice", "render", &invoice_id]));
    assert!(!paid_rendered.contains("Status:"), "{paid_rendered}");
    assert!(
        paid_rendered.contains("Paid:     USD 220.00"),
        "{paid_rendered}"
    );
    assert!(
        paid_rendered.contains("Balance:  USD 0.00"),
        "{paid_rendered}"
    );

    let saved_json = fs::read_to_string(&store).unwrap();
    assert!(saved_json.contains("\"schemaVersion\": 2"), "{saved_json}");
    assert!(
        saved_json.contains("\"paymentAcceptanceDetails\""),
        "{saved_json}"
    );
    assert!(
        saved_json.contains("\"acceptedPaymentDetailIDs\""),
        "{saved_json}"
    );
    assert!(
        saved_json.contains("\"unitPriceMinorUnits\": 10000"),
        "{saved_json}"
    );
}

#[test]
fn seed_sample_summary_and_backup_match_local_first_store_behavior() {
    let store = temp_store("seed-backup");

    assert_success(run(&store, &["seed-sample", "--force"]));
    let initial_json = fs::read_to_string(&store).unwrap();
    assert!(
        initial_json.contains("InvoiceGen Creative"),
        "{initial_json}"
    );
    assert!(
        initial_json.contains("\"paymentAcceptanceDetails\""),
        "{initial_json}"
    );

    let summary = assert_success(run(&store, &["summary"]));
    assert!(summary.contains("Outstanding:"), "{summary}");
    assert!(summary.contains("Paid to Date:"), "{summary}");
    assert!(summary.contains("Total Clients: 2"), "{summary}");
    assert!(summary.contains("Overdue Invoices:"), "{summary}");

    assert_success(run(
        &store,
        &["profile", "set", "--name", "Updated Business"],
    ));
    let backup = store.with_extension("json.bak");
    let backup_json = fs::read_to_string(&backup).unwrap();
    assert!(backup_json.contains("InvoiceGen Creative"), "{backup_json}");
    let updated_json = fs::read_to_string(&store).unwrap();
    assert!(updated_json.contains("Updated Business"), "{updated_json}");
}

#[test]
fn cli_loads_legacy_swift_store_with_missing_v2_fields() {
    let store = temp_store("legacy");
    fs::create_dir_all(store.parent().unwrap()).unwrap();
    fs::write(
        &store,
        r#"{
          "schemaVersion": 1,
          "businessProfile": {
            "name": "Legacy Co",
            "email": "",
            "address": "",
            "taxIdentifier": "",
            "currencyCode": "USD",
            "paymentTermsDays": 14
          },
          "clients": [],
          "projects": [],
          "invoices": [
            {
              "id": "00000000-0000-0000-0000-000000000201",
              "number": "INV-LEGACY",
              "issueDate": "2026-01-01T00:00:00Z",
              "dueDate": "2026-01-15T00:00:00Z"
            }
          ]
        }"#,
    )
    .unwrap();

    let list = assert_success(run(&store, &["invoice", "list"]));
    assert!(list.contains("INV-LEGACY"), "{list}");

    let rendered = assert_success(run(
        &store,
        &["invoice", "render", "00000000-0000-0000-0000-000000000201"],
    ));
    assert!(rendered.contains("INVOICE INV-LEGACY"), "{rendered}");
    assert!(
        rendered.contains("Bill To: Unassigned client"),
        "{rendered}"
    );
    assert!(
        rendered.contains("Terms\nPayment due on receipt."),
        "{rendered}"
    );
}
