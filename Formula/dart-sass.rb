class DartSass < Formula
  desc "Reference implementation of Sass, written in Dart"
  homepage "https://sass-lang.com/dart-sass"
  url "https://github.com/sass/dart-sass/archive/refs/tags/1.107.0.tar.gz"
  sha256 "df71b5d88d00bd3c8e19af8bb7e6c244a801519f5ee41b9f0e9106cbb38dca81"
  license "MIT"

  # Some tags are used for sass-api/sass-parser
  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "italoag/intel/buf" => :build
  depends_on "italoag/intel/dart-sdk" => :build
  depends_on "italoag/intel/dartaotruntime"

  # 1.107.0 needs `fatal_deprecation_except` from sass/sass main, which is not
  # in a tagged embedded protocol release yet (EMBEDDED_PROTOCOL_VERSION is still 3.3.0)
  resource "language" do
    url "https://github.com/sass/sass/archive/53e8d7548be7dc56b13e6914a82eedd69f0bd719.tar.gz"
    version "3.3.0"
    sha256 "f639f6ff603d89bd190bdf215b5caf4d11a29680db9f8c810782c888f36b5de8"

    livecheck do
      url :url
      regex(/embedded-protocol[._-]v?(\d+(?:\.\d+)+)/i)
    end
  end

  def install
    ENV["PUB_ENVIRONMENT"] = "homebrew:sass"
    ENV["DART_SUPPRESS_ANALYTICS"] = "true"

    (buildpath/"build/language").install resource("language")

    system "dart", "pub", "get"
    with_env(UPDATE_SASS_PROTOCOL: "false") do
      system "dart", "run", "grinder", "protobuf"
    end

    args = %W[
      -Dversion=#{version}
      -Ddart-version=#{Formula["italoag/intel/dart-sdk"].version}
      -Dcompiler-version=#{version}
      -Dprotocol-version=#{resource("language").version}
    ]
    system "dart", "compile", "aot-snapshot", "--output", "sass.aot", *args, "bin/sass.dart"
    libexec.install "sass.aot"

    (bin/"sass").write <<~BASH
      #!/bin/bash
      exec "#{formula_opt_bin("dartaotruntime")}/dartaotruntime" "#{libexec}/sass.aot" "$@"
    BASH
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sass --version")

    (testpath/"test.scss").write(".class {property: 1 + 1}")
    assert_match "property: 2;", shell_output("#{bin}/sass test.scss 2>&1")

    (testpath/"input.scss").write <<~SCSS
      div {
        img {
          border: 0px;
        }
      }
    SCSS

    assert_equal "div img{border:0px}",
    shell_output("#{bin}/sass --style compressed input.scss").strip
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "c088b1144c3d5665ec4aa35446daaabce0dca6f286cbde89525891d2f7d649fe"
  end

end
