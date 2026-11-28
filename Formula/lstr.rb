class Lstr < Formula
  desc "Fast, minimalist directory tree viewer"
  homepage "https://github.com/bgreenwell/lstr"
  url "https://github.com/bgreenwell/lstr/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "9b9fe1c43027e6fdc04b67bd60ebfa10166797a4810bdaa9087c0aa817fd6943"
  license "MIT"
  head "https://github.com/bgreenwell/lstr.git", branch: "devel"


  depends_on "italoag/intel/rust" => :build

  on_linux do
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lstr --version")

    (testpath/"test_dir/file1.txt").write "Hello, World!"
    assert_match "file1.txt", shell_output("#{bin}/lstr test_dir")
  end
end
