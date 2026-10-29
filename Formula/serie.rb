class Serie < Formula
  desc "A rich git commit graph in your terminal, like magic"
  homepage "https://github.com/lusingander/serie"
  version "0.10.1"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/lusingander/serie/releases/download/v0.10.1/serie-0.10.1-aarch64-apple-darwin.tar.gz"
      sha256 "1d206d78612f82142b4f156b7f02a84765c036b6d248e7b3d69840e0a6478aa6"
    end
    if Hardware::CPU.intel?
      url "https://github.com/lusingander/serie/releases/download/v0.10.1/serie-0.10.1-x86_64-apple-darwin.tar.gz"
      sha256 "8494f893af181cc9be620fd1bdff9f335efae9abe99fd1940746cccea72ee05e"
    end
  end

  def install
    bin.install "serie"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "01eae7519c14270b1651d9cdf0132282a88716eeb52021b29821692244cb5628"
  end

end
