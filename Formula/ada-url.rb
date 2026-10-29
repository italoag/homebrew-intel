class AdaUrl < Formula
  desc "WHATWG-compliant and fast URL parser written in modern C++"
  homepage "https://ada-url.com"
  url "https://github.com/ada-url/ada/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "6d6c7ef7dd2e329320d34eb2ab29ccdc879ee3935af9dfb894a6640e58dc381d"
  license any_of: ["Apache-2.0", "MIT"]
  revision 1
  compatibility_version 2
  head "https://github.com/ada-url/ada.git", branch: "main"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/cxxopts" => :build
  depends_on "italoag/intel/fmt"
  depends_on "italoag/intel/simdutf"

  uses_from_macos "italoag/intel/python@3.15" => :build

  on_macos do
    depends_on "italoag/intel/llvm" if DevelopmentTools.clang_build_version <= 1500
  end

  fails_with :clang do
    build 1500
    cause "Requires C++20 support"
  end

  fails_with :gcc do
    version "11"
    cause "Requires C++20"
  end

  deny_network_access!

  def install
    # ld: unknown options: --gc-sections
    if OS.mac? && DevelopmentTools.clang_build_version <= 1500
      inreplace "tools/cli/CMakeLists.txt", 'target_link_options(adaparse PRIVATE "-Wl,--gc-sections")', ""
    end
    # Do not statically link to libstdc++
    inreplace "tools/cli/CMakeLists.txt", 'target_link_options(adaparse PRIVATE "-static-libstdc++")', "" if OS.linux?

    # CPM/FetchContent args are to allow using our newer `simdutf`
    args = %W[
      -DCMAKE_INSTALL_RPATH=#{rpath}
      -DBUILD_SHARED_LIBS=ON
      -DADA_TOOLS=ON
      -DADA_USE_SIMDUTF=ON
      -DCPM_USE_LOCAL_PACKAGES=ON
      -DHOMEBREW_ALLOW_FETCHCONTENT=ON
      -DFETCHCONTENT_FULLY_DISCONNECTED=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cpp").write <<~CPP
      #include "ada.h"
      #include <iostream>

      int main(int , char *[]) {
        auto url = ada::parse<ada::url_aggregator>("https://www.github.com/ada-url/ada");
        url->set_protocol("http");
        std::cout << url->get_protocol() << std::endl;
        return EXIT_SUCCESS;
      }
    CPP

    system ENV.cxx, "test.cpp", "-std=c++20", "-I#{include}", "-L#{lib}", "-lada", "-o", "test"
    assert_equal "http:", shell_output("./test").chomp

    require "pty"
    output_log = testpath/"output.log"
    test_url = "http://www.google.com/bal?a==11#fddfds"
    pid = PTY.spawn(bin/"adaparse", "-d", test_url, [:out, :err] => output_log.to_s).last
    Process.wait(pid)
    assert_match "search_start 25", output_log.read
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "3a617f817554abd4848a929a552cae587c453ba3a18b89756a9b93fcd0accbe6"
  end

end
