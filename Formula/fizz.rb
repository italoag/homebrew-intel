class Fizz < Formula
  desc "C++14 implementation of the TLS-1.3 standard"
  homepage "https://github.com/facebookincubator/fizz"
  url "https://github.com/facebookincubator/fizz/archive/refs/tags/v2026.11.23.00.tar.gz"
  sha256 "9f8c278d601acbc789b7a90dd0c869c04c7a408866e3d725ccb2b4e3e8da52d6"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/facebookincubator/fizz.git", branch: "main"


  depends_on "italoag/intel/cmake" => [:build, :test]
  depends_on "italoag/intel/gflags" => :build
  depends_on "italoag/intel/libevent" => :build
  depends_on "italoag/intel/fmt"
  depends_on "italoag/intel/folly"
  depends_on "italoag/intel/glog"
  depends_on "italoag/intel/libsodium"
  depends_on "italoag/intel/openssl@4"
  depends_on "italoag/intel/zstd"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def install
    args = %W[
      -DBUILD_EXAMPLES=OFF
      -DBUILD_TESTS=OFF
      -DBUILD_SHARED_LIBS=ON
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]
    if OS.mac?
      # Prevent indirect linkage with boost and snappy.
      args += %w[
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,-dead_strip_dylibs
        -DCMAKE_SHARED_LINKER_FLAGS=-Wl,-dead_strip_dylibs
      ]
    end
    system "cmake", "-S", "fizz", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # `libsodium` does not install a CMake package configuration file. There
    # is a find module (at least in 1.0.20 tarball), but upstream has deleted
    # it in HEAD. Also, find modules are usually not shipped by upstream[^1].
    #
    # Since fizz-config.cmake requires FindSodium.cmake[^2], we save a copy in
    # libexec that can be used internally for testing `fizz` and dependents.
    #
    # [^1]: https://cmake.org/cmake/help/latest/manual/cmake-packages.7.html#find-module-packages
    # [^2]: https://github.com/facebookincubator/fizz/issues/141
    (libexec/"cmake").install "build/fbcode_builder/CMake/FindSodium.cmake"
  end

  test do
    (testpath/"test.cpp").write <<~CPP
      #include <fizz/client/AsyncFizzClient.h>
      #include <iostream>

      int main() {
        auto context = fizz::client::FizzClientContext();
        std::cout << toString(context.getSupportedVersions()[0]) << std::endl;
      }
    CPP

    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 4.0)
      project(test LANGUAGES CXX)
      set(CMAKE_CXX_STANDARD 20)

      list(APPEND CMAKE_MODULE_PATH "#{libexec}/cmake")
      find_package(gflags REQUIRED)
      find_package(fizz CONFIG REQUIRED)

      add_executable(test test.cpp)
      target_link_libraries(test fizz::fizz)
    CMAKE

    ENV.delete "CPATH"

    openssl_prefix = dep("openssl").opt_prefix
    args = ["-DCMAKE_PREFIX_PATH=#{openssl_prefix}"]
    args << "-DCMAKE_BUILD_RPATH=#{lib};#{HOMEBREW_PREFIX}/lib" if OS.linux?
    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    assert_match "TLS", shell_output("./build/test")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "fef4617e6370f7970e023b638aa99da830abb3c9516cd6ae7bd2e4d1bac69977"
  end

end
