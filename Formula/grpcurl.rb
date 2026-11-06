class Grpcurl < Formula
  desc "Like cURL, but for gRPC"
  homepage "https://www.fullstory.com/resources/content/fullstory-engineering-blog/"
  license "MIT"
  head "https://github.com/fullstorydev/grpcurl.git", branch: "master"

  stable do
    url "https://github.com/fullstorydev/grpcurl/archive/refs/tags/v1.9.4.tar.gz"
    sha256 "bea899ba2f483a951bf40aa05d41e069dd2f7bfe52d2a229717abfdb5620cb7c"

    # Fix Go 1.27 JSONv2 compatibility
    patch do
      url "https://github.com/fullstorydev/grpcurl/commit/cfa6ff68868284de47db88318a835c00b36d8777.patch?full_index=1"
      sha256 "e4efd7be56266b2665e88e92c4805691b6c540cc1973c786f0e1a922c777d678"
      type :backport
    end
  end


  depends_on "italoag/intel/go" => :build

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
    sha256 cellar: :any_skip_relocation, tahoe: "ea409c45f3b5ed128caac67e303d2f40e4910aae2d3945c1818533254ee6a489"
  end

end
