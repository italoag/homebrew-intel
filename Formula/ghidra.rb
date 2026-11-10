class Ghidra < Formula
  desc "Multi-platform software reverse engineering framework"
  homepage "https://github.com/NationalSecurityAgency/ghidra"
  url "https://github.com/NationalSecurityAgency/ghidra/archive/refs/tags/Ghidra_12.2_build.tar.gz"
  sha256 "ade4fd6e277a10c82db4e75ff5acaeedb3113ef0c7d126ea2c8b38c37128f3c3"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(/^Ghidra[._-]v?(\d+(?:\.\d+)+)(?:[._-]build)?$/i)
  end


  depends_on "italoag/intel/gradle" => :build
  depends_on "italoag/intel/python@3.15" => :build
  depends_on "italoag/intel/openjdk@25"

  def install
    ENV["JAVA_HOME"] = Language::Java.java_home("25")
    inreplace "Ghidra/application.properties", "DEV", "PUBLIC" # Mark as a release
    system "gradle", "-I", "gradle/support/fetchDependencies.gradle"

    system "gradle", "buildNatives"
    system "gradle", "assembleAll"

    libexec.install (buildpath/"build/dist/ghidra_#{version}_PUBLIC").children
    (bin/"ghidraRun").write_env_script libexec/"ghidraRun",
                                       Language::Java.overridable_java_home_env("25")
    (bin/"pyghidraRun").write_env_script libexec/"support/pyghidraRun",
                                         Language::Java.overridable_java_home_env("25")

    # remove incompatible native binaries
    os = OS.mac? ? "mac" : "linux"
    arch = Hardware::CPU.arm? ? "arm_64" : "x86_64"
    (libexec/"GPL/DemanglerGnu/os").children
                                   .each { |dir| rm_r(dir) if dir.basename.to_s != "#{os}_#{arch}" }
    (libexec/"Ghidra/Features").glob("{Decompiler,FileFormats}/os/*")
                               .each { |dir| rm_r(dir) if dir.basename.to_s != "#{os}_#{arch}" }
  end

  test do
    (testpath/"analyzeHeadless").write_env_script libexec/"support/analyzeHeadless",
                                                  Language::Java.overridable_java_home_env("25")
    (testpath/"project").mkpath
    system "/bin/bash", testpath/"analyzeHeadless", testpath/"project",
                        "HomebrewTest", "-import", "/bin/bash", "-noanalysis"
    assert_path_exists testpath/"project/HomebrewTest.rep"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "ba489247fa5c3bbfe7eb84807eedaa650502f61af536bc1bb68e43c853eb1e0c"
  end

end
