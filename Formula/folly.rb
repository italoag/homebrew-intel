class Folly < Formula
  desc "Collection of reusable C++ library artifacts developed at Facebook"
  homepage "https://github.com/facebook/folly"
  url "https://github.com/facebook/folly/archive/refs/tags/v2026.10.26.00.tar.gz"
  sha256 "b47fe04b804adfb51c65cda6b171505e67b9d1d69621106e54697821d1bf7ebc"
  license "Apache-2.0"
  compatibility_version 1
  head "https://github.com/facebook/folly.git", branch: "main"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/fast_float" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/boost"
  depends_on "italoag/intel/double-conversion"
  depends_on "italoag/intel/fmt"
  depends_on "italoag/intel/gflags"
  depends_on "italoag/intel/glog"
  depends_on "italoag/intel/libevent"
  depends_on "italoag/intel/libsodium"
  depends_on "italoag/intel/lz4"
  depends_on "italoag/intel/openssl@4"
  depends_on "italoag/intel/snappy"
  depends_on "italoag/intel/xz"
  depends_on "italoag/intel/zstd"

  uses_from_macos "bzip2"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def install
    args = %w[
      -DFOLLY_USE_JEMALLOC=OFF
    ]

    system "cmake", "-S", ".", "-B", "build/shared",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *args, *std_cmake_args
    system "cmake", "--build", "build/shared"
    system "cmake", "--install", "build/shared"

    system "cmake", "-S", ".", "-B", "build/static",
                    "-DBUILD_SHARED_LIBS=OFF",
                    *args, *std_cmake_args
    system "cmake", "--build", "build/static"
    lib.install "build/static/libfolly.a", "build/static/folly/libfollybenchmark.a"
  end

  test do
    (testpath/"test.cc").write <<~CPP
      #include <folly/FBVector.h>
      int main() {
        folly::fbvector<int> numbers({0, 1, 2, 3});
        numbers.reserve(10);
        for (int i = 4; i < 10; i++) {
          numbers.push_back(i * 2);
        }
        assert(numbers[6] == 12);
        return 0;
      }
    CPP
    system ENV.cxx, "-std=c++20", "test.cc", "-I#{include}", "-L#{lib}", "-lfolly", "-o", "test"
    system "./test"
  end
  patch do
    file "Patches/folly/remove-mno-sse2.diff"
  end

end
