class DartSdk < Formula
  desc "Dart Language SDK, including the VM, dart2js, core libraries, and more"
  homepage "https://dart.dev"
  url "https://github.com/dart-lang/sdk.git",
      tag:      "3.14.0",
      revision: "fa8c1270c374c1346931583a17c3b7f278d3822d"
  license "BSD-3-Clause"
  compatibility_version 4

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/rust" => :build

  uses_from_macos "curl" => :build
  uses_from_macos "italoag/intel/python@3.15" => :build
  uses_from_macos "italoag/intel/xz" => :build

  on_macos do
    depends_on xcode: :build # for xcodebuild
  end

  # always pull the latest commit from https://chromium.googlesource.com/chromium/tools/depot_tools.git/+/refs/heads/main
  resource "depot-tools" do
    url "https://chromium.googlesource.com/chromium/tools/depot_tools.git",
        revision: "43956b3e74de59b07bf8931ba9a472d622fe86a7"
    version "43956b3e74de59b07bf8931ba9a472d622fe86a7"

    livecheck do
      url "https://chromium.googlesource.com/chromium/tools/depot_tools.git/+/refs/heads/main?format=JSON"
      regex(/"commit":\s*"(\h+)"/i)
    end
  end

  allow_network_access! :test

  def fetch
    (buildpath/"sdk-src").install buildpath.children
    (buildpath/"depot-tools").install resource("depot-tools")
    mv "sdk-src", "sdk"

    ENV["DEPOT_TOOLS_UPDATE"] = "0"
    ENV.append_path "PATH", buildpath/"depot-tools"

    system "gclient", "config", "--name", "sdk", "file://#{buildpath}/sdk"
    system "gclient", "sync", "--no-history"
  end

  def install
    cd "sdk" do
      # Avoid hanging when the bootstrap SDK's VM service cannot bind to localhost in the sandbox
      inreplace "utils/ddc/BUILD.gn", '"--no-source-maps",', '"--no-source-maps", "--omit-memory-summary",'
      arch = Hardware::CPU.intel? ? "x64" : Hardware::CPU.arch.to_s
      out = OS.mac? ? "xcodebuild" : "out"
      system "./tools/build.py", "--mode=release", "--arch=#{arch}", "create_sdk"
      libexec.install Dir["#{out}/Release#{arch.upcase}/dart-sdk/*"]
    end
    bin.install_symlink libexec/"bin/dart"
  end

  test do
    system bin/"dart", "create", "dart-test"
    cd "dart-test" do
      assert_match "Hello world: 42!", shell_output("#{bin}/dart run")
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "12cfeb915fa957d620ef6f9f323fa517455a82b6bba30206e14d4d85307cfd7b"
  end

end
