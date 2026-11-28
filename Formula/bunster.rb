class Bunster < Formula
  desc "Compile shell scripts to static binaries"
  homepage "https://bunster.netlify.app/"
  url "https://github.com/yassinebenaid/bunster/archive/refs/tags/v0.14.0.tar.gz"
  sha256 "bab301b4365b0937537154afca867ec989cfe3f2d2233fabfbfa245882abaa1e"
  license "BSD-3-Clause"
  head "https://github.com/yassinebenaid/bunster.git", branch: "master"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "121127f27ee456e96b6085df7f17bbbf100a633178833ae859c6e0e0a1d85cee"
  end

  depends_on "italoag/intel/go"

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args, "./cmd/bunster"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bunster --version")

    (testpath/"test.sh").write <<~SHELL
      #!/bin/bash
      echo "Hello, World!"
    SHELL

    system bin/"bunster", "build", "test.sh", "-o", "test-binary"
    assert_path_exists testpath/"test-binary"
    assert_match "Hello, World!", shell_output("./test-binary")
  end
end
