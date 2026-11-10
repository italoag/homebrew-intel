class Zerobrew < Formula
  desc "Fast package manager alternative to Homebrew, written in Rust"
  homepage "https://github.com/lucasgelfond/zerobrew"
  version "0.1.1"
  license all_of: ["Apache-2.0", "MIT"]

  on_macos do
    on_arm do
      url "https://github.com/lucasgelfond/zerobrew/releases/download/v0.1.1/zb-darwin-arm64"
      sha256 "167b63b5a1a031d566ef7839b3d98c1eaa94680320ded5131b5200d2f157f17b"
    end
    on_intel do
      url "https://github.com/lucasgelfond/zerobrew/releases/download/v0.1.1/zb-darwin-x64"
      sha256 "522c2f7787adf3f97bf01927c7863e0e0214192af3fec8f46293293d2e325a82"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/lucasgelfond/zerobrew/releases/download/v0.1.1/zb-linux-arm64"
      sha256 "7abbce068aa0840057af66448a9c4c9a6f4ad5d01b08900de5f4c41e3de7b9ac"
    end
    on_intel do
      url "https://github.com/lucasgelfond/zerobrew/releases/download/v0.1.1/zb-linux-x64"
      sha256 "41d3ac764f5837b14eeec068e603bca9d5267e37a57520aa9eb464ef9e320006"
    end
  end

  def install
    if OS.mac?
      bin.install "zb-darwin-#{Hardware::CPU.arm? ? "arm64" : "x64"}" => "zb"
    else
      bin.install "zb-linux-#{Hardware::CPU.arm? ? "arm64" : "x64"}" => "zb"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/zb --version")
  end

end
