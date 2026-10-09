class Grpcurl < Formula
  desc "Like cURL, but for gRPC"
  homepage "https://www.fullstory.com/resources/content/fullstory-engineering-blog/"
  url "https://github.com/fullstorydev/grpcurl/archive/refs/tags/v1.9.4.tar.gz"
  sha256 "bea899ba2f483a951bf40aa05d41e069dd2f7bfe52d2a229717abfdb5620cb7c"
  license "MIT"
  head "https://github.com/fullstorydev/grpcurl.git", branch: "master"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "7621bbcb831f714192480f958b628a7f879924197d0072104b7dc0a8d9d286cf"
  end


  # TODO: unpin go@1.26 when grpcurl supports go 1.27
  # ref: https://github.com/fullstorydev/grpcurl/issues/568
  depends_on "go@1.26" => :build

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
end
