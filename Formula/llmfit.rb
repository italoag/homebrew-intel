class Llmfit < Formula
  desc "Find what models run on your hardware"
  homepage "https://github.com/AlexsJones/llmfit"
  url "https://static.crates.io/crates/llmfit/llmfit-1.1.21.crate"
  sha256 "33b841786bde9c052a9e44aebeb0db143157303a1f60db71acd9bd7005153305"
  license "MIT"
  head "https://github.com/AlexsJones/llmfit.git", branch: "main"


  depends_on "italoag/intel/rust" => :build

  allow_network_access! :test

  def fetch
    system "cargo", "fetch", "--locked"
  end

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/llmfit --version")
    assert_match(/Found \d+ model\(s\)/i, shell_output("#{bin}/llmfit search llama"))
  end

end
