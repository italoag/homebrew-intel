# Formula/lstr.rb

class Lstr < Formula
  desc "A fast, minimalist directory tree viewer"
  homepage "https://github.com/bgreenwell/lstr"
  # This version will be updated automatically by our release workflow
  version "0.2.1" # This should match the latest release
  license "MIT"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "402194db1c65850609dd3ce72eeb61a7777a0f548c9cfb1382b7313f16665bfd"
  end

  # Define URLs and checksums for both architectures
  if Hardware::CPU.intel?
    url "https://github.com/bgreenwell/lstr/releases/download/v0.2.1/lstr-macos-x86_64.tar.gz"
    sha256 "554108574d4de9cfe9207dd3937e9b9d3df2b4cadfb66a9d2c4376bbff6a25df"
  else
    url "https://github.com/bgreenwell/lstr/releases/download/v0.2.1/lstr-macos-arm64.tar.gz"
    sha256 "6b7fae4229d3d317defc774b9de5d079fb439fa2c40bb1e01b4099e182a8680c"
  end

  def install
    # The tarball contains the 'lstr' binary, README, and LICENSE.
    # We just need to install the binary.
    bin.install "lstr"
  end

  # Optional: Add a test block to verify the installation
  test do
    system "#{bin}/lstr", "--version"
  end
end

