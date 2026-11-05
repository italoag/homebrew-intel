class Maturin < Formula
  desc "Build and publish Rust crates as Python packages"
  homepage "https://github.com/PyO3/maturin"
  url "https://github.com/PyO3/maturin/archive/refs/tags/v1.16.0.tar.gz"
  sha256 "b22d15b7dc4f27af50b831af0866bcd901bcce2433182c5b2f252dd420531c0d"
  license any_of: ["Apache-2.0", "MIT"]
  compatibility_version 1
  head "https://github.com/PyO3/maturin.git", branch: "main"


  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/rust" => [:build, :test]
  depends_on "italoag/intel/python@3.15" => :test
  depends_on "italoag/intel/xz"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"maturin", "completions")

    python_versions = Formula.names.filter_map do |name|
      Version.new(name.delete_prefix("python@")) if name.start_with?("python@")
    end.sort

    newest_python = python_versions.pop
    newest_python_site_packages = lib/"python#{newest_python}/site-packages"
    newest_python_site_packages.install "maturin"

    python_versions.each do |pyver|
      (lib/"python#{pyver}/site-packages/maturin").install_symlink (newest_python_site_packages/"maturin").children
    end
  end

  test do
    system "cargo", "init", "homebrew", "--name=brew", "--bin"
    cd "homebrew" do
      system bin/"maturin", "build", "-o", "dist", "--compatibility", "off"
      system python3, "-m", "pip", "install", "brew", "--prefix=./dist", "--no-index", "--find-links=./dist"
      system python3, "-c", "import maturin"
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "f622a9ad393b3203436c931f6e2a9e837a9f13ab02edfd30fc86040b2b5731c2"
  end

end
