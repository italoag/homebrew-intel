class Ffmpegthumbnailer < Formula
  desc "Create thumbnails for your video files"
  homepage "https://github.com/dirkvdb/ffmpegthumbnailer"
  url "https://github.com/dirkvdb/ffmpegthumbnailer/archive/refs/tags/v2.3.1.tar.gz"
  sha256 "0691647dc054179c358794c643a0968f796d23c015d02283e6ce2cf4173d2e0a"
  license "GPL-2.0-or-later"
  head "https://github.com/dirkvdb/ffmpegthumbnailer.git", branch: "master"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/ffmpeg"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/libpng"

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    "-DENABLE_GIO=ON",
                    "-DENABLE_TESTS=OFF",
                    "-DENABLE_THUMBNAILER=ON",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    ffmpeg = formula_opt_bin("ffmpeg")/"ffmpeg"
    png = test_fixtures("test.png")
    system ffmpeg.to_s, "-loop", "1", "-i", png.to_s, "-c:v", "libx264", "-t", "30",
                        "-pix_fmt", "yuv420p", "v.mp4"
    assert_path_exists testpath/"v.mp4", "Failed to generate source video!"
    system bin/"ffmpegthumbnailer", "-i", "v.mp4", "-o", "out.jpg"
    assert_path_exists testpath/"out.jpg", "Failed to create thumbnail!"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "00550d408009214ddf7c21fd9f796b2ce07302cfb8404c23a8aaf7f91db53bca"
  end

end
