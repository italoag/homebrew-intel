class Cffi < Formula
  desc "C Foreign Function Interface for Python"
  homepage "https://cffi.readthedocs.io/en/latest/"
  url "https://files.pythonhosted.org/packages/9e/ef/008a1939e372c06329a3fce4279c02f328488f3526744906eeec3da7ad5f/cffi-2.1.1.tar.gz"
  sha256 "dd31f52ea1086513bb9df30f8fcee9b8918323ae067a3d5b78bc826a000712be"
  license "MIT-0"
  revision 1
  compatibility_version 1


  depends_on "italoag/intel/python-setuptools" => :build
  depends_on "italoag/intel/python@3.14" => [:build, :test]
  depends_on "italoag/intel/python@3.15" => [:build, :test]
  depends_on "italoag/intel/pycparser"

  uses_from_macos "italoag/intel/libffi"

  pypi_packages exclude_packages: "pycparser"

  deny_network_access!

  def install
    python3_interpreters.each do |python|
      system python, "-m", "pip", "install", *std_pip_args, "."
    end
  end

  test do
    assert_empty resources, "This formula should not have any resources!"
    (testpath/"sum.c").write <<~C
      int sum(int a, int b) { return a + b; }
    C

    libsum = testpath/shared_library("libsum")
    system ENV.cc, "-shared", "sum.c", "-o", libsum

    (testpath/"sum.py").write <<~PYTHON
      from cffi import FFI
      ffi = FFI()

      declaration = """
        int sum(int a, int b);
      """

      ffi.cdef(declaration)
      lib = ffi.dlopen("#{libsum}")
      print(lib.sum(1, 2))
    PYTHON

    python3_interpreters.each do |python|
      assert_equal 3, shell_output("#{python} sum.py").to_i
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any_skip_relocation, tahoe: "47224a7c74588c3c7e216ad8983949d91625b30b0be81ce994b0f157e69ac91a"
  end

end
