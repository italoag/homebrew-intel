class Grpcurl < Formula
  desc "Like cURL, but for gRPC"
  homepage "https://www.fullstory.com/resources/content/fullstory-engineering-blog/"
  url "https://github.com/fullstorydev/grpcurl/archive/refs/tags/v1.9.4.tar.gz"
  sha256 "bea899ba2f483a951bf40aa05d41e069dd2f7bfe52d2a229717abfdb5620cb7c"
  license "MIT"
  head "https://github.com/fullstorydev/grpcurl.git", branch: "master"


  # TODO: unpin go@1.26 when grpcurl supports go 1.27
  # ref: https://github.com/fullstorydev/grpcurl/issues/568
  depends_on "italoag/intel/go@1.26" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    system "go", "build", *std_go_args(ldflags: "-X main.version=#{version}"), "./cmd/grpcurl"
  end

  test do
    (testpath/"test.proto").write <<~PROTO
      syntax = "proto3";
      package test;
      message HelloWorld {
        string hello_world = 1;
      }
    PROTO
    system bin/"grpcurl", "-msg-template", "-proto", "test.proto", "describe", "test.HelloWorld"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "78faac0b94b11d38382de2d5e40778ddd44a682277474facb9ca0aeb8b2d81e0"
  end

end
