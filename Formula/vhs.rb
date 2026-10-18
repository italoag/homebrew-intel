class Vhs < Formula
  desc "Your CLI home video recorder"
  homepage "https://github.com/charmbracelet/vhs"
  url "https://github.com/charmbracelet/vhs/archive/refs/tags/v0.12.1.tar.gz"
  sha256 "ba9fbcb40133d1734c580ccb6b0fcae9673bf51d227f00877ac581c56ad15b77"
  license "MIT"
  head "https://github.com/charmbracelet/vhs.git", branch: "main"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "cbd0ec36796d16d436f935d551f5c37167d3b5e1e18700ac602c8c1df7216762"
  end


  depends_on "go" => :build
  depends_on "ffmpeg"
  depends_on "ttyd"

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(ldflags: "-X main.Version=#{version}")

    (man1/"vhs.1").write Utils.safe_popen_read(bin/"vhs", "man")

    generate_completions_from_executable(bin/"vhs", shell_parameter_format: :cobra)
  end

  test do
    (testpath/"test.tape").write <<~TAPE
      Output test.gif
      Type "Foo Bar"
      Enter
      Sleep 1s
    TAPE

    system bin/"vhs", "validate", "test.tape"

    assert_match version.to_s, shell_output("#{bin}/vhs --version")
  end
end
