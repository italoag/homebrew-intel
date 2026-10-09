class Aria2 < Formula
  desc "Download with resuming and segmented downloading"
  homepage "https://aria2.github.io/"
  url "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0.tar.xz"
  sha256 "60a420ad7085eb616cb6e2bdf0a7206d68ff3d37fb5a956dc44242eb2f79b66b"
  license "GPL-2.0-or-later"
  revision 3

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "550f7f50cceb98bb567710c9c1974fdf450ed23c95bfe72948e939a76e943312"
  end


  depends_on "pkgconf" => :build
  depends_on "c-ares"
  depends_on "libssh2"
  depends_on "openssl@4"
  depends_on "sqlite"

  uses_from_macos "libxml2"

  on_macos do
    depends_on "gettext"
  end

  on_linux do
    depends_on "zlib-ng-compat"
  end

  # Apply open PR to support OpenSSL 4
  patch do
    url "https://github.com/aria2/aria2/commit/11b1905b1df26c7e074387b3df2c44f814355863.patch?full_index=1"
    sha256 "97c7784eeba35e24bfc309d15b1dc6dfab1655dcd67fc2d03be439d06ad371cf"
    type :unofficial
    resolves "https://github.com/aria2/aria2/pull/2403"
  end

  # Test downloads a file from the network
  allow_network_access! :test

  def install
    ENV.append "LIBS", "-framework Security" if OS.mac?

    args = %w[
      --disable-silent-rules
      --with-libssh2
      --without-gnutls
      --without-libgmp
      --without-libnettle
      --without-libgcrypt
      --without-appletls
      --with-openssl
    ]

    system "./configure", *args, *std_configure_args
    system "make", "install"

    bash_completion.install "doc/bash_completion/aria2c"
  end

  test do
    system bin/"aria2c", "https://brew.sh/"
    assert_path_exists testpath/"index.html", "Failed to create index.html!"
  end
end
