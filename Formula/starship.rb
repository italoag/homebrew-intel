class Starship < Formula
  desc "Cross-shell prompt for astronauts"
  homepage "https://starship.rs/"
  url "https://github.com/starship/starship/archive/refs/tags/v1.27.0.tar.gz"
  sha256 "f1887ffa88a7ba437d2932501794047e28d03387996f7d1c364631c053cffc44"
  license "ISC"
  head "https://github.com/starship/starship.git", branch: "main"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/rust" => :build

  on_linux do
    depends_on "dbus"
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args

    generate_completions_from_executable(bin/"starship", "completions")
  end

  test do
    ENV["STARSHIP_CONFIG"] = ""
    assert_equal "[1;32m❯[0m ", shell_output("#{bin}/starship module character")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "54041cd1f0d03af8e244c6fcb96023296f6eeacfffe93873071cc276ffa671cb"
  end

end
