class Localai < Formula
  desc "OpenAI alternative"
  homepage "https://localai.io"
  url "https://github.com/mudler/LocalAI/releases/download/v5.0.1/LocalAI-v5.0.1-source.tar.gz"
  sha256 "d2ca736513a89a56761e5ba5d1c9659db177ad605855cb3b66a94b61d5a559f7"
  license "MIT"
  head "https://github.com/mudler/LocalAI.git", branch: "master"


  depends_on "italoag/intel/go" => :build
  depends_on "italoag/intel/node" => :build
  depends_on "italoag/intel/protobuf" => :build
  depends_on "italoag/intel/protoc-gen-go" => :build
  depends_on "italoag/intel/protoc-gen-go-grpc" => :build

  def install
    ENV["SDKROOT"] = MacOS.sdk_path if OS.mac?

    system "make", "build", "VERSION=#{version}"
    bin.install "local-ai"
  end

  test do
    addr = "127.0.0.1:#{free_port}"

    # The add-on owner opens `/` at startup, which the Linux test sandbox denies
    with_test_process(bin/"local-ai", "run", "--address", addr, "--addons-enabled=false") do
      sleep 5

      response = shell_output("curl -s -i #{addr}/readyz")
      assert_match "HTTP/1.1 200 OK", response
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "b3231cabb6b0d4e78ae42d03fb3e870fea780ba51c9d2036ccf5e7df61cd2c24"
  end

end
