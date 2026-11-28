class Fish < Formula
  desc "User-friendly command-line shell for UNIX-like operating systems"
  homepage "https://fishshell.com"
  url "https://github.com/fish-shell/fish-shell/releases/download/4.9.3/fish-4.9.3.tar.xz"
  sha256 "20998a25f73217ddcc19f499055fd587e9912d1ad6e7109120fbcf2871f0b98c"
  license "GPL-2.0-only"
  compatibility_version 1
  head "https://github.com/fish-shell/fish-shell.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/rust" => :build
  depends_on "italoag/intel/sphinx-doc" => :build
  depends_on "italoag/intel/pcre2"

  # Fix inline install code parsing with CMake 4.5.
  patch do
    url "https://github.com/chenrui333/fish-shell/commit/33502c2cc0c38ccfea820dbe364858273ef70fa8.patch?full_index=1"
    sha256 "63f6db1de990fec0d60dcb8b1365c96fa09dd39e40fd649e33358373ec3474f6"
    type :unofficial
    resolves "https://github.com/fish-shell/fish-shell/pull/13097"
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    args = %W[
      -DCMAKE_INSTALL_SYSCONFDIR=#{etc}
      -DWITH_DOCS=ON
      -Dextra_functionsdir=#{HOMEBREW_PREFIX}/share/fish/vendor_functions.d
      -Dextra_completionsdir=#{HOMEBREW_PREFIX}/share/fish/vendor_completions.d
      -Dextra_confdir=#{HOMEBREW_PREFIX}/share/fish/vendor_conf.d
    ]
    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    system bin/"fish", "-c", "echo"
    output = shell_output("#{bin}/fish -c 'set --show fish_function_path'")
    assert_match "#{HOMEBREW_PREFIX}/share/fish/vendor_functions.d", output
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "aa27be567f4d22e4ea704527a1076bf1c971c5c85df5fe18aa9561def296de23"
  end

end
