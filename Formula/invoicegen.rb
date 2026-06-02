class Invoicegen < Formula
  desc "Local-first invoice management CLI"
  homepage "https://github.com/megabyte0x/invoicegen"
  url "https://github.com/megabyte0x/invoicegen/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "REPLACE_WITH_SOURCE_TARBALL_SHA256"
  license "MIT"
  head "https://github.com/megabyte0x/invoicegen.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--locked", "--path", ".", "--root", prefix
    bin.install_symlink bin/"invoicegen-rs" => "invoicegen"
  end

  test do
    assert_match "InvoiceGen Rust CLI", shell_output("#{bin}/invoicegen --help")
  end
end
