class Notmuch < Formula
  include Language::Python::Shebang

  desc "Thread-based email index, search, and tagging"
  homepage "https://notmuchmail.org/"
  url "https://notmuchmail.org/releases/notmuch-0.40.tar.xz"
  sha256 "4b4314bbf1c2029fdf793637e6c7bb15c1b1730d22be9aa04803c98c5bbc446f"
  license "GPL-3.0-or-later"
  revision 2
  compatibility_version 1
  head "https://git.notmuchmail.org/git/notmuch", using: :git, branch: "master"

  livecheck do
    url "https://notmuchmail.org/releases/"
    regex(/href=.*?notmuch[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  depends_on "italoag/intel/doxygen" => :build
  depends_on "italoag/intel/emacs" => :build
  depends_on "italoag/intel/gnupg" => :build
  depends_on "italoag/intel/libgpg-error" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/sphinx-doc" => :build

  depends_on "italoag/intel/cffi"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/gmime"
  depends_on "italoag/intel/python@3.15"
  depends_on "italoag/intel/sfsexp"
  depends_on "italoag/intel/talloc"
  depends_on "italoag/intel/xapian"

  on_macos do
    depends_on "italoag/intel/gettext"
  end

  on_linux do
    depends_on "zlib-ng-compat"
  end

  def install
    ENV.append "CXXFLAGS", "-std=c++17"
    site_packages = Language::Python.site_packages(python3)
    with_env(PYTHONPATH: formula_opt_libexec("sphinx-doc")/site_packages) do
      system "./configure", "--prefix=#{prefix}",
                            "--mandir=#{man}",
                            "--emacslispdir=#{elisp}",
                            "--emacsetcdir=#{elisp}",
                            "--bashcompletiondir=#{bash_completion}",
                            "--zshcompletiondir=#{zsh_completion}",
                            "--without-ruby"
      system "make", "V=1", "install"
    end
    bin.install "notmuch-git"
    rewrite_shebang detected_python_shebang, bin/"notmuch-git"

    elisp.install Pathname.glob("emacs/*.el")
    bash_completion.install "completion/notmuch-completion.bash" => "notmuch"

    (prefix/"vim/plugin").install "vim/notmuch.vim"
    (prefix/"vim/doc").install "vim/notmuch.txt"
    (prefix/"vim").install "vim/syntax"

    system python3, "-m", "pip", "install", *std_pip_args(build_isolation: true), "./bindings/python-cffi"
  end

  test do
    (testpath/".notmuch-config").write <<~INI
      [database]
      path=#{testpath}/Mail
    INI
    (testpath/"Mail").mkpath
    assert_match "0 total", shell_output("#{bin}/notmuch new")

    system python3, "-c", <<~PYTHON
      import notmuch2
      db = notmuch2.Database(mode=notmuch2.Database.MODE.READ_ONLY)
      assert str(db.path) == '#{testpath}/Mail', 'Wrong db.path!'
      db.close()
    PYTHON
    system bin/"notmuch-git", "-C", testpath/"git", "init"
    assert_path_exists testpath/"git"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "f8cab36ec9227c429c99038033f8f2df2f341acbab518f361143533680d9e0a4"
  end

end
