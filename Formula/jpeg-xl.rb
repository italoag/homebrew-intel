class JpegXl < Formula
  desc "New file format for still image compression"
  homepage "https://jpeg.org/jpegxl/index.html"
  url "https://github.com/libjxl/libjxl/archive/refs/tags/v0.13.0.tar.gz"
  sha256 "24d18c9af2d1f5a17730b3f8d3f70a5c16e5ac303f5d9d5fe9dc00cf7ca82af2"
  license "BSD-3-Clause"
  compatibility_version 3

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  depends_on "italoag/intel/asciidoc" => :build
  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/docbook-xsl" => :build
  depends_on "italoag/intel/pkgconf" => [:build, :test]
  depends_on "italoag/intel/sphinx-doc" => :build
  depends_on "italoag/intel/webp" => :build
  depends_on "italoag/intel/brotli"
  depends_on "italoag/intel/giflib"
  depends_on "italoag/intel/highway"
  depends_on "italoag/intel/imath"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/libpng"
  depends_on "italoag/intel/little-cms2"
  depends_on "italoag/intel/openexr"

  uses_from_macos "libxml2" => :build
  uses_from_macos "libxslt" => :build # for xsltproc

  # These resources are versioned according to the script supplied with jpeg-xl to download the dependencies:
  # https://github.com/libjxl/libjxl/tree/v#{version}/third_party
  resource "sjpeg" do
    url "https://github.com/webmproject/sjpeg/archive/dd4d9857c58a25713711a46d37385ad23ca2177e.tar.gz"
    version "dd4d9857c58a25713711a46d37385ad23ca2177e"
    sha256 "94ee1d632b32ed9a1487afde078705fdf5772e8f1f54d80e7cb283b8f0ef8a95"

    livecheck do
      url "https://raw.githubusercontent.com/libjxl/libjxl/refs/tags/v#{LATEST_VERSION}/deps.sh"
      regex(/THIRD_PARTY_SJPEG="(\h+)"/i)
    end
  end

  deny_network_access!

  def install
    ENV.append_path "XML_CATALOG_FILES", etc/"xml/catalog"
    resources.each { |r| r.stage buildpath/"third_party"/r.name }
    system "cmake", "-S", ".", "-B", "build",
                    "-DJPEGXL_FORCE_SYSTEM_BROTLI=ON",
                    "-DJPEGXL_FORCE_SYSTEM_LCMS2=ON",
                    "-DJPEGXL_FORCE_SYSTEM_HWY=ON",
                    "-DJPEGXL_ENABLE_DEVTOOLS=ON",
                    "-DJPEGXL_ENABLE_DOXYGEN=OFF",
                    "-DJPEGXL_ENABLE_MANPAGES=ON",
                    "-DJPEGXL_ENABLE_JNI=OFF",
                    "-DJPEGXL_ENABLE_JPEGLI=OFF",
                    "-DJPEGXL_ENABLE_SKCMS=OFF",
                    "-DJPEGXL_VERSION=#{version}",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Avoid rebuilding dependents that hard-code the prefix.
    inreplace (lib/"pkgconfig").glob("*.pc"), prefix, opt_prefix
  end

  test do
    system bin/"cjxl", test_fixtures("test.jpg"), "test.jxl"
    assert_path_exists testpath/"test.jxl"

    (testpath/"jxl_test.c").write <<~C
      #include <jxl/encode.h>
      #include <stdlib.h>

      int main()
      {
          JxlEncoder* enc = JxlEncoderCreate(NULL);
          if (enc == NULL) {
            return EXIT_FAILURE;
          }
          JxlEncoderDestroy(enc);
          return EXIT_SUCCESS;
      }
    C
    jxl_flags = shell_output("pkgconf --cflags --libs libjxl").chomp.split
    system ENV.cc, "jxl_test.c", *jxl_flags, "-o", "jxl_test"
    system "./jxl_test"

    (testpath/"jxl_threads_test.c").write <<~C
      #include <jxl/thread_parallel_runner.h>
      #include <stdlib.h>

      int main()
      {
          void* runner = JxlThreadParallelRunnerCreate(NULL, 1);
          if (runner == NULL) {
            return EXIT_FAILURE;
          }
          JxlThreadParallelRunnerDestroy(runner);
          return EXIT_SUCCESS;
      }
    C
    jxl_threads_flags = shell_output("pkgconf --cflags --libs libjxl_threads").chomp.split
    system ENV.cc, "jxl_threads_test.c", *jxl_threads_flags, "-o", "jxl_threads_test"
    system "./jxl_threads_test"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "1d00d785d181d4ebf95747a39e26d22906e7b76add76f6bf61f3de5cd3c884fc"
  end

end
