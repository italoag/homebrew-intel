class Openexr < Formula
  desc "High dynamic-range image file format"
  homepage "https://www.openexr.com/"
  url "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.5.5.tar.gz"
  sha256 "c31d62f76cec06f738d4521f4062b51977e3cf6fb2644a1d505de3d291d78e2d"
  license "BSD-3-Clause"
  compatibility_version 2


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/pkgconf" => :build

  depends_on "italoag/intel/imath"
  depends_on "italoag/intel/libdeflate"
  depends_on "italoag/intel/openjph"
  depends_on "italoag/intel/zstd"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  # These used to be provided by `ilmbase`
  link_overwrite "include/OpenEXR"
  link_overwrite "lib/libIex.dylib"
  link_overwrite "lib/libIex.so"
  link_overwrite "lib/libIlmThread.dylib"
  link_overwrite "lib/libIlmThread.so"

  resource "homebrew-exr", :test do
    url "https://github.com/AcademySoftwareFoundation/openexr-images/raw/f17e353fbfcde3406fe02675f4d92aeae422a560/TestImages/AllHalfValues.exr"
    sha256 "eede573a0b59b79f21de15ee9d3b7649d58d8f2a8e7787ea34f192db3b3c84a4"
  end

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource("homebrew-exr").stage do
      system bin/"exrheader", "AllHalfValues.exr"
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "bacad608fd27f7e51bff06588720d5fca522a6a7d221a51d423927555ba36273"
  end

end
