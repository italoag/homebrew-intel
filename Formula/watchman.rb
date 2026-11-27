class Watchman < Formula
  include Language::Python::Shebang

  desc "Watch files and take action when they change"
  homepage "https://meta.github.io/watchman/"
  url "https://github.com/meta/watchman/archive/refs/tags/v2026.11.23.00.tar.gz"
  sha256 "513a78c03fef7706eec77548c8f9d02f37215c5987e067bb4c462451b930fc9e"
  license "MIT"
  head "https://github.com/meta/watchman.git", branch: "main"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/cpptoml" => :build
  depends_on "italoag/intel/gflags" => :build
  depends_on "italoag/intel/googletest" => :build
  depends_on "italoag/intel/libevent" => :build
  depends_on "italoag/intel/mvfst" => :build
  depends_on "italoag/intel/openssl@4" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/python-setuptools" => :build
  depends_on "italoag/intel/rust" => :build
  depends_on "italoag/intel/edencommon"
  depends_on "italoag/intel/fb303"
  depends_on "italoag/intel/fbthrift"
  depends_on "italoag/intel/fmt"
  depends_on "italoag/intel/folly"
  depends_on "italoag/intel/glog"
  depends_on "italoag/intel/pcre2"
  depends_on "italoag/intel/python@3.15"

  on_linux do
    depends_on "libunwind"
    depends_on "italoag/intel/openssl@4"
  end

  def install
    # Match the F14 ABI in bottled Folly instead of compiling for the host CPU.
    if OS.linux? && Tab.for_formula(Formula["italoag/intel/folly"]).built_as_bottle
      ENV["HOMEBREW_OPTFLAGS"] = Hardware::CPU.optimization_flags.fetch(Hardware.oldest_cpu)
    end

    # NOTE: Setting `BUILD_SHARED_LIBS=ON` will generate DSOs for Eden libraries.
    #       These libraries are not part of any install targets and have the wrong
    #       RPATHs configured, so will need to be installed and relocated manually
    #       if they are built as shared libraries. They're not used by any other
    #       formulae, so let's link them statically instead. This is done by default.
    build_user = tap&.user || "Homebrew"
    openssl_prefix = dep("openssl").opt_prefix
    args = %W[
      -DENABLE_EDEN_SUPPORT=ON
      -DPython3_EXECUTABLE=#{python3}
      -DWATCHMAN_VERSION_OVERRIDE=#{version}
      -DWATCHMAN_BUILDINFO_OVERRIDE=#{build_user}
      -DWATCHMAN_USE_XDG_STATE_HOME=ON
      -DCMAKE_CXX_STANDARD=20
      -DOPENSSL_ROOT_DIR=#{openssl_prefix}
    ]
    # Avoid overlinking with libsodium and mvfst
    args << "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-dead_strip_dylibs" if OS.mac?

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    path = Pathname.new(File.join(prefix, HOMEBREW_PREFIX))
    bin.install (path/"bin").children
    lib.install (path/"lib").children
    rm_r(path)

    rewrite_shebang detected_python_shebang, *bin.children
  end

  test do
    assert_equal(version.to_s, shell_output("#{bin}/watchman -v").chomp)
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "03312d47b3c7b641cd5f806fe2f11ce102e4f1f0349def4d036ba53d8d18c20b"
  end

end
