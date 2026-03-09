class Kamis < Formula
  desc "Karlsruhe Maximum Independent Sets - exact and heuristic solvers for MIS and MWIS"
  homepage "https://github.com/KarlsruheMIS/KaMIS"
  url "https://github.com/KarlsruheMIS/KaMIS/archive/refs/tags/v3.1.tar.gz"
  sha256 "0af2b5dd4604075281152a8b2296e2617e43c85861bb432f5ea023058796d385"
  license "MIT"

  # KaHIP submodule required for mmwis build (mmwis/extern/KaHIP)
  resource "kahip" do
    url "https://github.com/KaHIP/KaHIP/archive/b6bedee5fdef49108ad8400389497192b6b23f64.tar.gz"
    sha256 "ab26e7e739e301036bdb1191f9fd0c55f1633038dfd0d2a0ba61852179ebd3ca"
  end

  depends_on "cmake" => :build
  depends_on "gcc"

  fails_with :clang do
    cause "Requires OpenMP support not available in Apple Clang"
  end

  def install
    # Remove -march=native from all CMakeLists.txt for bottle portability
    %w[
      CMakeLists.txt
      wmis/CMakeLists.txt
      mmwis/CMakeLists.txt
      mmwis/extern/struction/CMakeLists.txt
    ].each do |f|
      if File.exist?(f)
        inreplace f, "-march=native", "-mtune=generic"
      end
    end

    # Place KaHIP submodule content for mmwis build.
    # GitHub tarballs exclude submodule content, so we fetch it as a resource.
    (buildpath/"mmwis/extern/KaHIP").rmtree if (buildpath/"mmwis/extern/KaHIP").exist?
    resource("kahip").stage do
      (buildpath/"mmwis/extern/KaHIP").install Dir["*"]
    end

    # Build 1: Main build (redumis, graphchecker, sort_adjacencies, online_mis, wmis/)
    system "cmake", "-S", ".", "-B", "build",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCMAKE_C_COMPILER=#{Formula["gcc"].opt_bin}/gcc-#{Formula["gcc"].version.major}",
                    "-DCMAKE_CXX_COMPILER=#{Formula["gcc"].opt_bin}/g++-#{Formula["gcc"].version.major}",
                    *std_cmake_args
    system "cmake", "--build", "build", "--parallel"

    # Build 2: MMWIS build (mmwis, struction)
    system "cmake", "-S", "mmwis", "-B", "mmwis/build",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCMAKE_C_COMPILER=#{Formula["gcc"].opt_bin}/gcc-#{Formula["gcc"].version.major}",
                    "-DCMAKE_CXX_COMPILER=#{Formula["gcc"].opt_bin}/g++-#{Formula["gcc"].version.major}",
                    *std_cmake_args
    system "cmake", "--build", "mmwis/build", "--parallel"

    # Install main binaries
    bin.install "build/redumis"
    bin.install "build/graphchecker"
    bin.install "build/sort_adjacencies"
    bin.install "build/online_mis"

    # Install wmis binaries with renamed names (matching upstream deploy convention)
    bin.install "build/wmis/branch_reduce" => "weighted_branch_reduce"
    bin.install "build/wmis/weighted_ls" => "weighted_local_search"

    # Install mmwis binaries
    bin.install "mmwis/build/mmwis"
    if File.exist?("mmwis/build/extern/struction/branch_reduce_convergence")
      bin.install "mmwis/build/extern/struction/branch_reduce_convergence" => "struction"
    end

    # Install examples
    pkgshare.install "examples"
  end

  test do
    # Create a simple test graph (METIS format): 4 nodes, 4 edges
    # Triangle with a pendant vertex
    (testpath/"test.graph").write <<~EOS
      4 4
      2 3
      1 3 4
      1 2
      2
    EOS

    # Run redumis and check it produces valid output
    output = shell_output("#{bin}/redumis #{testpath}/test.graph --time_limit=5 --console_log")
    assert_match(/Independent set has size/, output)

    # Verify graphchecker works
    output = shell_output("#{bin}/graphchecker #{testpath}/test.graph")
    assert_match(/graph/, output.downcase)
  end
end
