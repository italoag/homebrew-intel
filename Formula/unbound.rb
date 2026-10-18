class Unbound < Formula
  desc "Validating, recursive, caching DNS resolver"
  homepage "https://www.unbound.net"
  url "https://nlnetlabs.nl/downloads/unbound/unbound-1.26.1.tar.gz"
  sha256 "35a6dc0e425a9282c3426d9a3043144011bf0534aed4b73ab62c52aee0af1503"
  license "BSD-3-Clause"
  revision 1
  compatibility_version 1
  head "https://github.com/NLnetLabs/unbound.git", branch: "master"

  # We check the GitHub repo tags instead of
  # https://nlnetlabs.nl/downloads/unbound/ since the first-party site has a
  # tendency to lead to an `execution expired` error.
  livecheck do
    url :head
    regex(/^(?:release-)?v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "9da420915a8c83be0eab96f894fc9e57a774d4590bc5806235d234a8e2688a3e"
  end


  depends_on "libevent"
  depends_on "libnghttp2"
  depends_on "openssl@4"

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
end
