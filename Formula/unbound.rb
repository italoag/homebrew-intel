class Unbound < Formula
  desc "Validating, recursive, caching DNS resolver"
  homepage "https://www.unbound.net"
  url "https://nlnetlabs.nl/downloads/unbound/unbound-1.26.2.tar.gz"
  sha256 "d8ee7aa6bbb3ff1be7d9e57637d0d0ec2f18273a8efff1a0afe2c665858b96f7"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/NLnetLabs/unbound.git", branch: "master"

  # We check the GitHub repo tags instead of
  # https://nlnetlabs.nl/downloads/unbound/ since the first-party site has a
  # tendency to lead to an `execution expired` error.
  livecheck do
    url :head
    regex(/^(?:release-)?v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "italoag/intel/libevent"
  depends_on "italoag/intel/libnghttp2"
  depends_on "italoag/intel/openssl@4"

  uses_from_macos "expat"

  deny_network_access!

  def install
    expat_prefix = OS.mac? ? "#{MacOS.sdk_for_formula(self).path}/usr" : formula_opt_prefix("expat")
    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}
      --enable-event-api
      --enable-tfo-client
      --enable-tfo-server
      --with-libevent=#{formula_opt_prefix("libevent")}
      --with-libexpat=#{expat_prefix}
      --with-libnghttp2=#{formula_opt_prefix("libnghttp2")}
      --with-ssl=#{formula_opt_prefix("openssl@4")}
    ]

    system "./configure", *args

    inreplace "doc/example.conf", 'username: "unbound"', 'username: "@@HOMEBREW-UNBOUND-USER@@"'
    system "make"
    system "make", "install"
  end

  post_install_steps do
    if_path_exists "{{etc}}/unbound/unbound.conf" do
      inreplace "unbound/unbound.conf", 'username: "@@HOMEBREW-UNBOUND-USER@@"', 'username: "{{user}}"',
                base: :etc, audit_result: false
    end
  end

  service do
    run [opt_sbin/"unbound", "-d", "-c", etc/"unbound/unbound.conf"]
    keep_alive true
    require_root true
  end

  test do
    system sbin/"unbound-control-setup", "-d", testpath
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "4515da0957e7de3ae76f0f96ba332673c3d1f287c58a62de6590ad9fd5ee80ee"
  end

end
