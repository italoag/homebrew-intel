class Upx < Formula
  desc "Compress/expand executable files"
  homepage "https://upx.github.io/"
  url "https://github.com/upx/upx/releases/download/v5.3.1/upx-5.3.1-src.tar.xz"
  sha256 "ece4a0cbbe9b6584de2e39d0d887b3ecdfd1648d5ad8e20266485a76de09c28a"
  license "GPL-2.0-or-later"
  head "https://github.com/upx/upx.git", branch: "devel"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/ucl" => :build

  on_linux do
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    system bin/"upx", "-1", "-o", "./hello", test_fixtures("elf/c.elf")
    assert_path_exists testpath/"hello"
    system bin/"upx", "-d", "./hello"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "f6a86bdd8ba2f123f8d30f606e1758cde201483eb10530300eb96a02180d9fa2"
  end

end
