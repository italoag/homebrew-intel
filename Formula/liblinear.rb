class Liblinear < Formula
  desc "Library for large linear classification"
  homepage "https://github.com/cjlin1/liblinear"
  url "https://github.com/cjlin1/liblinear/archive/refs/tags/v250.tar.gz"
  version "2.50"
  sha256 "c875bab4d5ae53a5b48a91081c66f39a0bd2524f49e934dcdaed90284dd605e4"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/cjlin1/liblinear.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d)(\d+)$/i)
    strategy :git do |tags, regex|
      tags.filter_map do |tag|
        match = tag.match(regex)
        next if match.blank?

        "#{match[1]}.#{match[2]}"
      end
    end
  end


  # Fix sonames
  patch :p0 do
    file "Patches/liblinear/patch-Makefile.diff"
  end

  deny_network_access!

  def install
    soversion_regex = /^SHVER = (\d+)$/
    soversion = (buildpath/"Makefile").read
                .lines
                .grep(soversion_regex)
                .first[soversion_regex, 1]
    system "make", "all"
    bin.install "predict", "train"
    lib.install shared_library("liblinear", soversion)
    lib.install_symlink shared_library("liblinear", soversion) => shared_library("liblinear")
    include.install "linear.h"
  end

  test do
    (testpath/"train_classification.txt").write <<~EOS
      +1 201:1.2 3148:1.8 3983:1 4882:1
      -1 874:0.3 3652:1.1 3963:1 6179:1
      +1 1168:1.2 3318:1.2 3938:1.8 4481:1
      +1 350:1 3082:1.5 3965:1 6122:0.2
      -1 99:1 3057:1 3957:1 5838:0.3
    EOS

    system bin/"train", "train_classification.txt"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "f08f462ac091b941403a09d567e5cc24cfe881e0485ddc673f92edab2b2a7d56"
  end

end
