class Ripgrep < Formula
  desc "Search tool like grep and The Silver Searcher"
  homepage "https://github.com/BurntSushi/ripgrep"
  url "https://github.com/BurntSushi/ripgrep/archive/refs/tags/16.0.0.tar.gz"
  sha256 "17e7a1a0db80ed9618a0963c7ae4aecb8fce25c70cf7ebed514daf2b38a0d153"
  license "Unlicense"
  compatibility_version 1
  head "https://github.com/BurntSushi/ripgrep.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end


  depends_on "italoag/intel/asciidoctor" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/rust" => :build
  depends_on "italoag/intel/pcre2"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args(features: "pcre2")

    generate_completions_from_executable(bin/"rg", "--generate", shell_parameter_format: "complete-")
    (man1/"rg.1").write Utils.safe_popen_read(bin/"rg", "--generate", "man")
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system bin/"rg", "Hello World!", testpath
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "361bb552cc86880d7d5eab72d3588d1468f389ecd347d715e43d32e50dfaa28e"
  end

end
