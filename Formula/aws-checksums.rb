class AwsChecksums < Formula
  desc "Cross-Platform HW accelerated CRC32c and CRC32 with fallback"
  homepage "https://github.com/awslabs/aws-checksums"
  url "https://github.com/awslabs/aws-checksums/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "b24d4896e8406ddff8080037936c86d539929369918265694bedcb887cbe602b"
  license "Apache-2.0"
  compatibility_version 2

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "affef5d0a4305e1dca55ea2e7626092f9a50347386c1d56f3c90ce2b82d6d46a"
  end


  depends_on "cmake" => :build
  depends_on "aws-c-common"

  deny_network_access!

  def install
    # Intel: https://github.com/awslabs/aws-checksums/commit/e03e976974d27491740c98f9132a38ee25fb27d0
    # ARM:   https://github.com/awslabs/aws-checksums/commit/d7005974347050a97b13285eb0108dd1e59cf2c4
    ENV.runtime_cpu_detection

    system "cmake", "-S", ".", "-B", "build", "-DBUILD_SHARED_LIBS=ON", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <aws/checksums/crc.h>
      #include <aws/common/allocator.h>
      #include <assert.h>

      int main(void) {
        struct aws_allocator *allocator = aws_default_allocator();
        const size_t len = 3 * 1024 * 1024 * 1024ULL;
        const uint8_t *many_zeroes = aws_mem_calloc(allocator, len, sizeof(uint8_t));
        uint32_t result = aws_checksums_crc32_ex(many_zeroes, len, 0);
        aws_mem_release(allocator, (void *)many_zeroes);
        assert(0x480BBE37 == result);
        return 0;
      }
    C
    system ENV.cc, "test.c", "-o", "test", "-L#{lib}", "-laws-checksums",
                   "-L#{formula_opt_lib("aws-c-common")}", "-laws-c-common"
    system "./test"
  end
end
