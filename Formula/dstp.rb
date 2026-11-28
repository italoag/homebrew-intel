class Dstp < Formula
  desc "Run common networking tests against your site"
  homepage "https://github.com/ycd/dstp"
  url "https://github.com/ycd/dstp/archive/refs/tags/v0.4.23.tar.gz"
  sha256 "1ab45012204cd68129fd05723dd768ea4a9ce08e2f6c2fa6468c2c88ab65c877"
  license "MIT"
  head "https://github.com/ycd/dstp.git", branch: "main"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "ee7874467a8e0bf4678584a75762e9f3b907aa6fb6e2a2d4e003486c027af266"
  end

  depends_on "italoag/intel/go" => :build

  allow_network_access! :test

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args, "./cmd/dstp"
  end

  test do
    assert_match "HTTPS: got 200 OK", shell_output("#{bin}/dstp example.com --dns 1.1.1.1")
  end
end
