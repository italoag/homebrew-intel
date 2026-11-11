class Serie < Formula
  desc "A rich git commit graph in your terminal, like magic"
  homepage "https://github.com/lusingander/serie"
  version "0.10.2"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/lusingander/serie/releases/download/v0.10.2/serie-0.10.2-aarch64-apple-darwin.tar.gz"
      sha256 "cbc878822b19b5aa06c08eaeaa0dcd570c54b48de9fbbba01c4e56458e00f358"
    end
    if Hardware::CPU.intel?
      url "https://github.com/lusingander/serie/releases/download/v0.10.2/serie-0.10.2-x86_64-apple-darwin.tar.gz"
      sha256 "128730f3fd0ffa5f0f7f8fc9b619b0210f30917af0b79ae7a07d27bdc7326805"
    end
  end

  def install
    bin.install "serie"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "361591618fda2d91e9c7796d6bb602726740b0a0207c1f223a4fe4475150d601"
  end

end
