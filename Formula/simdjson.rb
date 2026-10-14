class Simdjson < Formula
  desc "SIMD-accelerated C++ JSON parser"
  homepage "https://simdjson.org"
  url "https://github.com/simdjson/simdjson/archive/refs/tags/v5.0.4.tar.gz"
  sha256 "827417bcf88309df170962e7bd1b4b4a4992d5d4e5cb82a0442ada9530e916d2"
  license "Apache-2.0"
  head "https://github.com/simdjson/simdjson.git", branch: "master"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "c49ba6e9dd29fc3a23d4cce3409d16b2aea86679791cbcc9691f57fb358eeea7"
  end


  depends_on "cmake" => :build

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DSIMDJSON_BUILD_STATIC_LIB=ON",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.json").write({ name: "Homebrew", isNull: nil }.to_json)
    (testpath/"test.cpp").write <<~CPP
      #include <iostream>
      #include <simdjson.h>
      int main(void) {
        simdjson::dom::parser parser;
        simdjson::dom::element json = parser.load("test.json");
        std::cout << json["name"] << std::endl;
      }
    CPP

    system ENV.cxx, "test.cpp", "-std=c++11",
           "-I#{include}", "-L#{lib}", "-lsimdjson", "-o", "test"
    assert_equal "\"Homebrew\"\n", shell_output("./test")
  end
end
