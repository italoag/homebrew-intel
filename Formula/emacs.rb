class Emacs < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftpmirror.gnu.org/emacs/emacs-31.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz"
  sha256 "1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586"
  license "GPL-3.0-or-later"
  revision 1
  compatibility_version 1

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "e533f0a03233cac873b73b169642ae5d2139049b12c05337ce83ec8af0d78ec8"
  end


  head do
    url "https://github.com/emacs-mirror/emacs.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "gnu-sed" => :build
  end

  depends_on "pkgconf" => :build
  depends_on "texinfo" => :build
  depends_on "gmp"
  depends_on "gnutls"
  depends_on "tree-sitter"

  uses_from_macos "libxml2"
  uses_from_macos "ncurses"

  on_linux do
    depends_on "jpeg-turbo"
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def install
    args = %W[
      --disable-acl
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
      --with-gnutls
      --without-x
      --with-xml2
      --without-dbus
      --with-modules
      --without-ns
      --without-imagemagick
      --without-selinux
      --with-tree-sitter
    ]

    if build.head?
      ENV.prepend_path "PATH", formula_opt_libexec("gnu-sed")/"gnubin"
      system "./autogen.sh"
    end

    File.write "lisp/site-load.el", <<~LISP
      (setq exec-path (delete nil
        (mapcar
          (lambda (elt)
            (unless (string-match-p "Homebrew/shims" elt) elt))
          exec-path)))
    LISP

    system "./configure", *args
    system "make"
    system "make", "install"
  end

  service do
    run [opt_bin/"emacs", "--fg-daemon"]
    keep_alive true
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
