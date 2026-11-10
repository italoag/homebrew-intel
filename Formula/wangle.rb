class Wangle < Formula
  desc "Modular, composable client/server abstractions framework"
  homepage "https://github.com/facebook/wangle"
  url "https://github.com/facebook/wangle/archive/refs/tags/v2026.10.26.00.tar.gz"
  sha256 "5c482135fbea0ca6359c2093f1b725e5abfbed205fa59cecb0ed2fb9234cfbf3"
  license "Apache-2.0"
  compatibility_version 1
  head "https://github.com/facebook/wangle.git", branch: "main"


  depends_on "italoag/intel/cmake" => [:build, :test]
  depends_on "italoag/intel/libevent" => :build
  depends_on "italoag/intel/double-conversion"
  depends_on "italoag/intel/fizz"
  depends_on "italoag/intel/fmt"
  depends_on "italoag/intel/folly"
  depends_on "italoag/intel/gflags"
  depends_on "italoag/intel/glog"
  depends_on "italoag/intel/openssl@4"

  allow_network_access! :test

  def install
    args = ["-DBUILD_TESTS=OFF"]
    # Prevent indirect linkage with boost, libsodium, snappy and xz
    args << "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-dead_strip_dylibs" if OS.mac?

    system "cmake", "-S", "wangle", "-B", "build/shared", "-DBUILD_SHARED_LIBS=ON", *args, *std_cmake_args
    system "cmake", "--build", "build/shared"
    system "cmake", "--install", "build/shared"

    system "cmake", "-S", "wangle", "-B", "build/static", "-DBUILD_SHARED_LIBS=OFF", *args, *std_cmake_args
    system "cmake", "--build", "build/static"
    lib.install "build/static/lib/libwangle.a"

    pkgshare.install Dir["wangle/example/echo/*.cpp"]
  end

  test do
    (testpath/"CMakeLists.txt").write <<~CMAKE
      cmake_minimum_required(VERSION 4.0)
      project(Echo LANGUAGES CXX)
      set(CMAKE_CXX_STANDARD 20)

      list(APPEND CMAKE_MODULE_PATH "#{formula_opt_libexec("fizz")}/cmake")
      find_package(gflags REQUIRED)
      find_package(folly CONFIG REQUIRED)
      find_package(fizz CONFIG REQUIRED)
      find_package(wangle CONFIG REQUIRED)

      add_executable(EchoClient #{pkgshare}/EchoClient.cpp)
      target_link_libraries(EchoClient wangle::wangle)
      add_executable(EchoServer #{pkgshare}/EchoServer.cpp)
      target_link_libraries(EchoServer wangle::wangle)
    CMAKE

    ENV.delete "CPATH"
    system "cmake", "-S", ".", "-B", "build", "-DCMAKE_MODULE_PATH=#{testpath}/cmake",
                    "-DCMAKE_BUILD_RPATH=#{HOMEBREW_PREFIX}/lib",
                    "-DOPENSSL_ROOT_DIR=#{formula_opt_prefix("openssl@4")}", "-Wno-author"
    system "cmake", "--build", "build"

    port = free_port
    spawn testpath/"build/EchoServer", "-port", port.to_s
    sleep 30

    require "pty"
    require "io/console"
    output = ""
    PTY.spawn(testpath/"build/EchoClient", "-host", "127.0.0.1", "-port", port.to_s) do |r, w, pid|
      r.noecho do
        w.write "Hello from Homebrew!\nAnother test line.\n"
        sleep 60
        Process.kill "TERM", pid
        begin
          r.each_line { |line| output += line }
        rescue Errno::EIO
          # GNU/Linux raises EIO when read is done on closed pty
        end
      end
    end
    assert_match("Hello from Homebrew!", output)
    assert_match("Another test line.", output)
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "4e19dec38e41d4e600a4e0ec4fe51106f82728eb05f9cf1015be21a04a66048a"
  end

end
