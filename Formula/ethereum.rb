class Ethereum < Formula
  desc "Official Go implementation of the Ethereum protocol"
  homepage "https://geth.ethereum.org/"
  url "https://github.com/ethereum/go-ethereum/archive/refs/tags/v1.17.9.tar.gz"
  sha256 "dce5d109fb2a29a740cc41ed9e5b78e1e4a08af8bc0899baaf8797bef68aa591"
  license "LGPL-3.0-or-later"
  head "https://github.com/ethereum/go-ethereum.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "f9d0f0d5550918bb6851b19180e15ba11163f879ea6db3401e67bb33d22af5d2"
  end


  depends_on "go" => :build

  deny_network_access!

  def fetch
    system "go", "mod", "download"
  end

  def install
    # Force superenv to use -O0 to fix "cgo-dwarf-inference:2:8: error:
    # enumerator value for '__cgo_enum__0' is not an integer constant".
    # See discussion in https://github.com/Homebrew/brew/issues/14763.
    ENV.O0 if OS.linux?

    ldflags = %W[
      -X github.com/ethereum/go-ethereum/internal/build/env.GitCommitFlag=#{tap.user}
      -X github.com/ethereum/go-ethereum/internal/build/env.GitTagFlag=v#{version}
      -X github.com/ethereum/go-ethereum/internal/build/env.BuildnumFlag=#{tap.user}
    ]
    (buildpath/"cmd").each_child(false) do |cmd|
      next if %w[keeper utils].include? cmd.basename.to_s

      system "go", "build", *std_go_args(ldflags:, output: bin/cmd), "./cmd/#{cmd}"
    end
  end

  test do
    (testpath/"genesis.json").write <<~JSON
      {
        "config": {
          "homesteadBlock": 10
        },
        "nonce": "0",
        "difficulty": "0x20000",
        "mixhash": "0x00000000000000000000000000000000000000647572616c65787365646c6578",
        "coinbase": "0x0000000000000000000000000000000000000000",
        "timestamp": "0x00",
        "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "extraData": "0x",
        "gasLimit": "0x2FEFD8",
        "alloc": {}
      }
    JSON

    system bin/"geth", "--datadir", "testchain", "init", "genesis.json"
    assert_path_exists testpath/"testchain/geth/chaindata/000002.log"
    assert_path_exists testpath/"testchain/geth/nodekey"
    assert_path_exists testpath/"testchain/geth/LOCK"
  end
end
