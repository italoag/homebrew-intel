class Tuios < Formula
  desc "Terminal UI OS (Terminal Multiplexer)"
  homepage "https://tuios.dev/"
  url "https://github.com/Gaurav-Gosain/tuios/archive/refs/tags/v0.13.1.tar.gz"
  sha256 "9f34163e076611002ff09780014d227d8b80efb0ad95dcd7bfa0e2c188971010"
  license "MIT"
  head "https://github.com/Gaurav-Gosain/tuios.git", branch: "main"


  depends_on "italoag/intel/go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(ldflags: :goreleaser), "./cmd/tuios"

    generate_completions_from_executable(bin/"tuios", shell_parameter_format: :cobra)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tuios --version")

    assert_match "git_hub_dark", shell_output("#{bin}/tuios --list-themes")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "31021d308c862ee784b31f5a91ad3db0632f3a7683223ca0c04f4e711d9e0916"
  end

end
