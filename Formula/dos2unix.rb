class Dos2unix < Formula
  desc "Convert text between DOS, UNIX, and Mac formats"
  homepage "https://waterlander.net/dos2unix/"
  url "https://waterlander.net/dos2unix/files/dos2unix-7.5.7.tar.gz"
  sha256 "669ee27120ae71589f638fe3a167d6ea54f8633f5ab1b282551bd7a7c9510dfa"
  license "BSD-2-Clause"

  livecheck do
    url :homepage
    regex(/href=.*?dos2unix[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "e0a27be0d83d958192254297f132cbe4e67af6c7c30c65ea701b452a4b04ea46"
  end


  deny_network_access!

  def install
    args = %W[
      prefix=#{prefix}
      CC=#{ENV.cc}
      CPP=#{ENV.cc}
      CFLAGS=#{ENV.cflags}
      ENABLE_NLS=
      install
    ]

    system "make", *args
  end

  test do
    # write a file with lf
    test_file = testpath/"test.txt"
    test_file.write "foo\nbar\n"

    # unix2mac: convert lf to cr
    system bin/"unix2mac", test_file
    assert_equal "foo\rbar\r", test_file.read

    # mac2unix: convert cr to lf
    system bin/"mac2unix", test_file
    assert_equal "foo\nbar\n", test_file.read

    # unix2dos: convert lf to cr+lf
    system bin/"unix2dos", test_file
    assert_equal "foo\r\nbar\r\n", test_file.read

    # dos2unix: convert cr+lf to lf
    system bin/"dos2unix", test_file
    assert_equal "foo\nbar\n", test_file.read
  end
end
