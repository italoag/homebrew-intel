class Bunster < Formula
  desc "Compile shell scripts to static binaries"
  homepage "https://bunster.netlify.app"
  url "https://github.com/yassinebenaid/bunster/releases/download/v0.14.0/bunster_darwin-amd64.tar.gz"
  sha256 "e9a91e0dcd48ef549c8b667e152de185d4d315bbcaa56e7c3f04574d6e1b8668"
  version "0.14.0"
  license "BSD-3-Clause"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "121127f27ee456e96b6085df7f17bbbf100a633178833ae859c6e0e0a1d85cee"
  end

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/yassinebenaid/bunster/releases/download/v0.14.0/bunster_darwin-arm64.tar.gz"
      sha256 "02f426854ff95c8b0360520fb442f90280241038ddd90d13331ec164c375ca6f"
    end
  end

  on_linux do
    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/yassinebenaid/bunster/releases/download/v0.14.0/bunster_linux-arm64.tar.gz"
      sha256 "17aefe4073441c740b83fbed3133e8b49fd9602f76dd62dadc8df95974b851bc"
    elsif Hardware::CPU.intel?
      if Hardware::CPU.is_64_bit?
        url "https://github.com/yassinebenaid/bunster/releases/download/v0.14.0/bunster_linux-amd64.tar.gz"
        sha256 "506d2e8170144f2d8e753608336551961d9f4c4c73d92156ccb42eb630a5df86"
      else
        url "https://github.com/yassinebenaid/bunster/releases/download/v0.14.0/bunster_linux-386.tar.gz"
        sha256 "465863f7d464a776ddf7032a177ef6db757de4d5ee4d7343788bbb6d12edf28c"
      end
    end
  end

  def install
    bin.install "bunster"
  end

  test do
    system "#{bin}/bunster", "--help"
  end
end
