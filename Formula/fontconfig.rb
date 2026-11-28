class Fontconfig < Formula
  desc "XML-based font configuration API for X Windows"
  homepage "https://wiki.freedesktop.org/www/Software/fontconfig/"
  url "https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/2.18.4/fontconfig-2.18.4.tar.gz"
  sha256 "cecf4125622ed674d5630b6deaeff43e3695afe197bdcc560363a1820d858112"
  license all_of: [
    "HPND-sell-variant",
    "Unicode-3.0",        # fc-case/CaseFolding.txt
    "MIT-Modern-Variant", # src/fcatomic.h, src/fcmutex.h
    "MIT",                # src/fcfoundry.h
    :public_domain,       # src/fcmd5.h, src/ftglue.[ch]
  ]
  compatibility_version 1
  head "https://gitlab.freedesktop.org/fontconfig/fontconfig.git", branch: "main"

  livecheck do
    url :stable
    regex(/v?(\d+\.\d+\.(?:\d|[0-8]\d+))/i)
  end


  depends_on "italoag/intel/gettext" => :build
  depends_on "italoag/intel/meson" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/freetype"

  uses_from_macos "gperf" => :build
  uses_from_macos "italoag/intel/python@3.15" => :build
  uses_from_macos "expat"

  on_macos do
    depends_on "italoag/intel/gettext"
  end

  deny_network_access!

  def install
    args = %W[
      --default-library=both
      --localstatedir=#{var}
      --sysconfdir=#{etc}
      -Ddoc=disabled
      -Dtests=disabled
      -Dtools=enabled
      -Dcache-build=disabled
      -Dadditional-fonts-dirs=no
    ]

    # Cannot use default dirs on macOS due to fc-cache recursing unnecessary directories
    # Issue ref: https://gitlab.freedesktop.org/fontconfig/fontconfig/-/work_items/547
    if OS.mac?
      font_dirs = %w[
        /System/Library/Fonts
        /Library/Fonts
        ~/Library/Fonts
      ]
      font_dirs << Dir["/System/Library/Assets{,V2}/com_apple_MobileAsset_Font*"].max

      args << "-Ddefault-fonts-dirs=#{font_dirs}"
    end

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  post_install_steps do
    run "fc-cache", args: ["--force", "--really-force", "--verbose"], base: :bin
  end

  test do
    system bin/"fc-list"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "459fa5639e6c53554e7bb4501f09f2dadf93ca9ff6e2b66a2246930c9e655d38"
  end

end
