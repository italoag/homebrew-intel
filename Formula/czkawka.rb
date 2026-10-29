class Czkawka < Formula
  desc "Duplicate file utility"
  homepage "https://github.com/qarmin/czkawka"
  url "https://github.com/qarmin/czkawka/archive/refs/tags/12.0.2.tar.gz"
  sha256 "b9e1722ac2625aa0c5861eac6499cafe9e4e7cc0bc9a429c8c3ad6c1e8cd68f1"
  license all_of: ["MIT", "CC-BY-4.0"]
  head "https://github.com/qarmin/czkawka.git", branch: "master"


  depends_on "italoag/intel/rust" => :build
  depends_on "italoag/intel/adwaita-icon-theme"
  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/dav1d"
  depends_on "italoag/intel/ffmpeg"
  depends_on "italoag/intel/gdk-pixbuf"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/gtk4"
  depends_on "italoag/intel/libheif"
  depends_on "italoag/intel/librsvg"
  depends_on "italoag/intel/pango"
  depends_on "italoag/intel/pkgconf"
  depends_on "italoag/intel/webp-pixbuf-loader"

  uses_from_macos "bzip2"

  on_macos do
    depends_on "italoag/intel/gettext"
    depends_on "italoag/intel/graphene"
    depends_on "italoag/intel/harfbuzz"
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    features = %w[heif libraw libavif]
    %w[czkawka_cli czkawka_gui krokiet].each do |cmd|
      system "cargo", "install", *std_cargo_args(path: cmd, features:)
    end
  end

  post_install_steps do
    compile_gsettings_schemas
  end

  def caveats
    <<~EOS
      czkawka_gui requires $XDG_DATA_DIRS to contain "#{HOMEBREW_PREFIX}/share".
    EOS
  end

  test do
    system bin/"czkawka_cli", "dup", "--directories", testpath, "--file-to-save", "results.txt"
    assert_match "Not found any duplicates", File.read("results.txt")

    assert_match version.to_s, shell_output("#{bin}/czkawka_cli --version")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "4a95f952f500829ed75d342e211563f9aa8f96b6f736417b79583043059ca99d"
  end

end
