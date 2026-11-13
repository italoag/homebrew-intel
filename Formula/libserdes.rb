class Libserdes < Formula
  desc "Schema ser/deserializer lib for Avro + Confluent Schema Registry"
  homepage "https://github.com/confluentinc/libserdes"
  url "https://github.com/confluentinc/libserdes.git",
      tag:      "v8.4.1",
      revision: "8cf97f7395bf5131d14bacfe896c6a5731b1f0c8"
  license "Apache-2.0"
  compatibility_version 1
  head "https://github.com/confluentinc/libserdes.git", branch: "master"


  depends_on "italoag/intel/avro-c"
  depends_on "italoag/intel/jansson"

  uses_from_macos "curl"

  on_macos do
    depends_on "italoag/intel/librdkafka"
  end

  deny_network_access!

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <err.h>
      #include <stddef.h>
      #include <sys/types.h>
      #include <libserdes/serdes.h>

      int main()
      {
        char errstr[512];
        serdes_conf_t *sconf = serdes_conf_new(NULL, 0, NULL);
        serdes_t *serdes = serdes_new(sconf, errstr, sizeof(errstr));
        if (serdes == NULL) {
          errx(1, "constructing serdes: %s", errstr);
        }
        serdes_destroy(serdes);
        return 0;
      }
    C
    system ENV.cc, "test.c", "-L#{lib}", "-lserdes", "-o", "test"
    system "./test"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "6c0a33c88016440ccc6122a12dc5d766c6d110e4153778257d63cdd203a4221c"
  end

end
