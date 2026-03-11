class Red2pack < Formula
  desc "Exact and heuristic solvers for the maximum (weight) 2-packing set problem"
  homepage "https://github.com/KarlsruheMIS/red2pack"
  url "https://github.com/KarlsruheMIS/red2pack/releases/download/v2.0.0/red2pack-2.0.0.tar.gz"
  sha256 "36d205915fe8d5da2564290ed3a4e520eeac9d5b0309385e58f6bda27b7e52c6"
  license "MIT"
  head "https://github.com/KarlsruheMIS/red2pack.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "gcc" => :build

  def install
    gcc = Formula["gcc"]
    gcc_version = gcc.version.major

    cmake_args = std_cmake_args.reject { |a| a.start_with?("-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=") }

    system "cmake", "-B", "build",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
                    "-DCMAKE_C_COMPILER=#{gcc.opt_bin}/gcc-#{gcc_version}",
                    "-DCMAKE_CXX_COMPILER=#{gcc.opt_bin}/g++-#{gcc_version}",
                    "-DCMAKE_C_FLAGS=-w",
                    "-DCMAKE_CXX_FLAGS=-w",
                    "-DRED2PACK_ENABLE_EXAMPLES=OFF",
                    *cmake_args
    system "cmake", "--build", "build", "-j#{ENV.make_jobs}"

    %w[
      red2pack_branch_and_reduce
      red2pack_heuristic
      redw2pack_drp
      redw2pack_reduce
      redw2pack_rnt_chils
      redw2pack_rnt_exact
      redw2pack_rnt_hils
      redw2pack_rnt_htwis
      redw2pack_rnt_mmwis
      redw2pack_transform
    ].each do |b|
      bin.install "build/app/#{b}"
    end
  end

  test do
    (testpath/"test.graph").write <<~EOS
      5 6
      2 3
      1 3 4
      1 2 4 5
      2 3 5
      3 4
    EOS
    output = shell_output("#{bin}/red2pack_heuristic #{testpath}/test.graph 2>&1")
    assert_match(/packing|solution|MIS|independent|time/i, output)
  end
end
