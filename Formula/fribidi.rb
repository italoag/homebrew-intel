class Fribidi < Formula
  desc "Implementation of the Unicode BiDi algorithm"
  homepage "https://github.com/fribidi/fribidi"
  url "https://github.com/fribidi/fribidi/releases/download/v1.0.18/fribidi-1.0.18.tar.xz"
  sha256 "1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later"]
  compatibility_version 1


  depends_on "italoag/intel/help2man" => :build
  depends_on "italoag/intel/pkgconf" => :build

  deny_network_access!

  def install
    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--enable-static"
    system "make", "install"
  end

  test do
    (testpath/"test.input").write <<~EOS
      a _lsimple _RteST_o th_oat
    EOS

    assert_match "a simple TSet that", shell_output("#{bin}/fribidi --charset=CapRTL --test test.input")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "8d8b009d981034bafb72f2666ff2710b8c00f64298a45948147aea1db4347bb4"
  end

end
