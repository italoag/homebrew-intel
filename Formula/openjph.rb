class Openjph < Formula
  desc "Open-source implementation of JPEG2000 Part-15 (or JPH or HTJ2K)"
  homepage "https://github.com/aous72/OpenJPH"
  url "https://github.com/aous72/OpenJPH/archive/refs/tags/0.33.0.tar.gz"
  sha256 "3437f296ff8531b35558650b0ed7fde45cad39394329eef4064a3d4900cf101f"
  license "BSD-2-Clause"
  compatibility_version 8
  head "https://github.com/aous72/OpenJPH.git", branch: "master"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/libtiff"

  resource "homebrew-test.ppm", :test do
    url "https://raw.githubusercontent.com/aous72/jp2k_test_codestreams/ca2d370/openjph/references/Malamute.ppm"
    sha256 "e4e36966d68a473a7f5f5719d9e41c8061f2d817f70a7de1c78d7e510a6391ff"
  end

  # Find Threads in the installed CMake config as targets now link it publicly
  patch do
    url "https://github.com/daeho-ro/OpenJPH/commit/3dfa201688b96f3b5dab3057bce89975ba7f2ad5.patch?full_index=1"
    sha256 "7cfd6ff20a8e86fa17a60132d3c1cacc7bd2c97d6b229cf26d4482488a1374c7"
    type :unofficial
    resolves "https://github.com/aous72/OpenJPH/pull/420"
  end

  deny_network_access!

  def install
    ENV["DYLD_LIBRARY_PATH"] = lib.to_s

    args = %W[
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource("homebrew-test.ppm").stage testpath

    system bin/"ojph_compress", "-i", "Malamute.ppm", "-o", "homebrew.j2c"
    system bin/"ojph_expand", "-i", "homebrew.j2c", "-o", "homebrew.ppm"
    assert_path_exists testpath/"homebrew.ppm"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "a82f5f22922d68e24a44d8a2a19cac0e2eb5fc1230b65dcbb8c340cf2bc1b35b"
  end

end
