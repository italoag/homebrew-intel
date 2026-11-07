class Gpgmepp < Formula
  desc "C++ bindings for gpgme"
  homepage "https://www.gnupg.org/related_software/gpgme/"
  url "https://www.gnupg.org/ftp/gcrypt/gpgmepp/gpgmepp-2.2.0.tar.xz"
  sha256 "6651c5f7f801543d5b676719df9fec8053b0a6f5aba40b98ca0d2bee11136f30"
  license "LGPL-2.1-or-later"
  compatibility_version 1

  livecheck do
    url "https://gnupg.org/ftp/gcrypt/gpgmepp/"
    regex(/href=.*?gpgmepp[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/pkgconf" => [:build, :test]
  depends_on "italoag/intel/gpgme"

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    pkgshare.install "tests"
  end

  test do
    cp_r (pkgshare/"tests").children, testpath

    flags = shell_output("pkgconf --cflags --libs gpgmepp").chomp.split
    system ENV.cxx, "-std=c++17", "run-genrandom.cpp", "-o", "test",
                    "-I#{include}/gpgme++", *flags
    system "./test", "--number", "10"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "ebae35dc3986e085c8673c72fc70fe8a90e7d23c6c5630e0340e8242b27dce74"
  end

end
