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

    assert_success(run(&store, &["invoice", "mark-paid", &invoice_id]));
    let paid_rendered = assert_success(run(&store, &["invoice", "render", &invoice_id]));
    assert!(
        paid_rendered.contains("Status:     Paid"),
        "{paid_rendered}"
    );
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
