class Upx < Formula
  desc "Compress/expand executable files"
  homepage "https://upx.github.io/"
  url "https://github.com/upx/upx/releases/download/v5.3.0/upx-5.3.0-src.tar.xz"
  sha256 "6229b5564dd91dd423a5280a7c15b70fc05449d2605bb853ce076743057fcf55"
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
    sha256 cellar: :any_skip_relocation, tahoe: "3e3698b6738f42482d504e878a064abff554d0301c01112628e4a5a44110e93e"
  end

end
