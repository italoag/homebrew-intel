class Xan < Formula
  desc "CSV CLI magician written in Rust"
  homepage "https://github.com/medialab/xan"
  url "https://github.com/medialab/xan/archive/refs/tags/0.61.0.tar.gz"
  sha256 "cd675a4ce734438f5b6b0eba28f5f1e275fdd58c387f03afc9eb37146779e18c"
  license any_of: ["MIT", "Unlicense"]
  head "https://github.com/medialab/xan.git", branch: "master"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "ab2e4d622f2056aebd930283287d3f70892d03104408fdd57ce31c9b81b74d9a"
  end


  depends_on "rust" => :build

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args(features: "parquet")
    generate_completions_from_executable(bin/"xan", "completions", shells: [:bash, :zsh])
  end

  test do
    (testpath/"test.csv").write("first header,second header")
    system bin/"xan", "stats", "test.csv"
    assert_match version.to_s, shell_output("#{bin}/xan --version").chomp
  end
end
