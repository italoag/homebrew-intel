class Tuios < Formula
  desc "Terminal UI OS (Terminal Multiplexer)"
  homepage "https://tuios.dev/"
  url "https://github.com/Gaurav-Gosain/tuios/archive/refs/tags/v0.13.3.tar.gz"
  sha256 "26ffb34240cc273eb7d0f3b6ee5a9a124c7c4a947f39fb22877ca2f93a539d73"
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
    sha256 cellar: :any_skip_relocation, tahoe: "777d4e305e793e659a4fb9beabd7b4ad82ba986c3d909c4348f2eb6c04a6bbf2"
  end

end
