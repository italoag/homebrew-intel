class Openexr < Formula
  desc "High dynamic-range image file format"
  homepage "https://www.openexr.com/"
  url "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.5.3.tar.gz"
  sha256 "ff1de95f4031c1c57c633e647dc97c15282d3aa3bc7fb90745f00f74de4a054f"
  license "BSD-3-Clause"
  revision 1
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
    sha256 cellar: :any, tahoe: "f6219c59751c176ec1e4cfbf2e2bd62130133da3bee601ce7e9b31199228ba66"
  end

end
