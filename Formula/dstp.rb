require 'rbconfig'
class Dstp < Formula
  desc "Run common networking tests against your site"
  homepage "https://github.com/ycd/dstp"
  version "0.4.23"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "ee7874467a8e0bf4678584a75762e9f3b907aa6fb6e2a2d4e003486c027af266"
  end

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/ycd/dstp/releases/download/v0.4.23/dstp_0.4.23_Darwin_amd64.tar.gz"
      sha256 "7bf240ccc7fcacc0905f231c7ee0b519d997ff0f42111610c1ff5af529d31520"
    end
    if Hardware::CPU.arm?
      url "https://github.com/ycd/dstp/releases/download/v0.4.23/dstp_0.4.23_Darwin_arm64.tar.gz" 
      sha256 "960eed0b4c2614d6ec493cebd5cd81a3119d9c21def6c90e1cef97d9f0a89db4"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ycd/dstp/releases/download/v0.4.23/dstp_0.4.23_Linux_amd64.tar.gz"
      sha256 "247e68a0fd9558d8751b155d13d1f18668ae22d549fb1e156e9cccc7325833ef"
    end
    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/ycd/dstp/releases/download/v0.4.23/dstp_0.4.23_Linux_arm64.tar.gz"
      sha256 "cf379b4d0fcdf8b987be1a481d1f4b86a90cfc54232fd675d04aa35a9c2df6dc"
    end
  end


  def install
    bin.install "dstp"
  end

  test do
    system "dstp"
  end

end
