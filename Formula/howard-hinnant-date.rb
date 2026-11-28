class HowardHinnantDate < Formula
  desc "C++ library for date and time operations based on <chrono>"
  homepage "https://github.com/HowardHinnant/date"
  url "https://github.com/HowardHinnant/date/archive/refs/tags/v3.0.6.tar.gz"
  sha256 "19f393877190e346ecbded5df4bbbb9bbfcc5aa57008becafeaacf5ea32d210b"
  license "MIT"
  compatibility_version 1


  depends_on "italoag/intel/cmake" => :build

  def install
    args = %w[
      -DENABLE_DATE_TESTING=OFF
      -DUSE_SYSTEM_TZ_DB=ON
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TZ_LIB=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cpp").write <<~CPP
      #include "date/tz.h"
      #include <iostream>

      int main() {
        auto t = date::make_zoned(date::current_zone(), std::chrono::system_clock::now());
        std::cout << t << std::endl;
      }
    CPP
    system ENV.cxx, "test.cpp", "-std=c++1y", "-L#{lib}", "-ldate-tz", "-o", "test"
    system "./test"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "abe24a6644607476e3cd3a9b4a03719c85791f7a53a4e5446deb72b31f1d1b42"
  end

end
