class Nmap < Formula
  desc "Port scanning utility for large networks"
  homepage "https://nmap.org/"
  url "https://nmap.org/dist/nmap-7.993.tar.bz2"
  sha256 "270e55f04915bfcecb5db8feb959d4c5ba86a48c094520a4f1c07571e1c79c59"
  license :cannot_represent
  compatibility_version 1

  livecheck do
    url "https://nmap.org/download"
    regex(/href=.*?nmap[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  head do
    url "https://svn.nmap.org/nmap/"

    depends_on "italoag/intel/autoconf" => :build
  end

  depends_on "italoag/intel/python-setuptools" => :build
  depends_on "italoag/intel/liblinear"
  depends_on "italoag/intel/libssh2"
  # Check supported Lua version at https://github.com/nmap/nmap/tree/master/liblua.
  depends_on "italoag/intel/lua"
  depends_on "italoag/intel/openssl@4"
  depends_on "italoag/intel/pcre2"
  depends_on "italoag/intel/python@3.15" # for ndiff

  uses_from_macos "italoag/intel/bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "libpcap"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  conflicts_with "cern-ndiff", "ndiff", because: "both install `ndiff` binaries"

  # needs a network connection to test
  allow_network_access! :test

  def install
    # Fix to missing VERSION file
    # https://github.com/nmap/nmap/pull/3111
    mv "libpcap/VERSION.txt", "libpcap/VERSION"

    ENV.deparallelize

    libpcap_path = OS.mac? ? MacOS.sdk_path/"usr/" : formula_opt_prefix("libpcap")

    args = %W[
      --with-liblua=#{formula_opt_prefix("lua")}
      --with-libpcre=#{formula_opt_prefix("pcre2")}
      --with-openssl=#{formula_opt_prefix("openssl@4")}
      --with-libpcap=#{libpcap_path}
      --without-nmap-update
      --disable-universal
      --without-zenmap
      --without-ndiff
    ]

    system "./configure", *args, *std_configure_args
    system "make" # separate steps required otherwise the build fails
    system "make", "install"

    # Install `ndiff` separately so that we can use `pip` and `setuptools`.
    system python3, "-m", "pip", "install", *std_pip_args, "./ndiff"
    bin.glob("uninstall_*").map(&:unlink) # Users should use brew uninstall.
  end

  test do
    system bin/"nmap", "-p80,443", "-oX", "scan1.xml", "google.com"
    cp "scan1.xml", "scan2.xml"
    system bin/"ndiff", "scan1.xml", "scan2.xml"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "900c8e1878d8fd7313d68a54e7836bbcd1784bb63996375d95f1c726e44b8f3e"
  end

end
