require "formula"
class Wt < Formula
    desc "Development libraries for Wt"
    homepage "http://www.webtoolkit.eu/wt/doc/reference/html/Releasenotes.html"
    url "https://github.com/kdeforche/wt/archive/3.3.5.tar.gz"
    sha256 "c136ce78ee00fe950071ab56a112b5d9a1fc19944b56a530b1826de865523eaf"

    option :universal
    option "without-docs", "Build API reference and manual pages"

    depends_on "cmake" => :build
    depends_on "pkg-config" => :build
    depends_on "boost" => :optional
    depends_on "fcgi" =>  :optional
    depends_on "openssl" => :optional
    depends_on "libpng" => :optional
    depends_on "libtiff" => :optional
    depends_on "libharu" => :optional
    depends_on "pango" => :optional
    depends_on "GraphicsMagick" => :optional
    depends_on "doxygen" => :build if build.with? "docs"
    depends_on "graphviz" => :build if build.with? "docs"

    patch :p1 do
        url "https://raw.githubusercontent.com/jamal-fuma/homebrew-packages/master/patches/wt-3.3.5/100-http-client-enhancements.patch"
        sha256 "8f2364dd357ac1c2fdaa2033930e318979378be0be56c4455c84973d91748d98"
    end

    def install
        optional_args = []
        if build.universal?
            ENV.universal_binary
            optional_args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
        end

        witty_args = [
            # openssl
            %q{-DSSL_PREFIX="/usr/local/Cellar/openssl/1.0.2e_1"},
            %q{-DENABLE_SSL=ON},

            # opengl
            %q{-DENABLE_OPENGL=ON},

            # pdf output
            %q{-DENABLE_HARU=ON},
            %q{-DENABLE_PANGO=ON},

            # sqlite
            %q{-DENABLE_SQLITE=ON},

            # mysql
            %q{-DENABLE_MYSQL=ON},

            # postgres
            %q{-DENABLE_POSTGRES=ON}
        ]

        witty_cmake_args = [
            %q{-DWT_CPP_11_MODE=-std=c++1y},

            # Unit tests
            %q{-DENABLE_LIBWTTEST=ON},

            # Database work
            %q{-DENABLE_LIBWTDBO=ON},
        ]

        cmake_compile_args = [
            #            %q{-DCMAKE_CXX_FLAGS=-stdlib=libc++},
            #            %q{-DCMAKE_EXE_LINKER_FLAGS=-stdlib=libc++},
            #            %q{-DCMAKE_MODULE_LINKER_FLAGS=-stdlib=libc++},
            %q{-DCMAKE_BUILD_TYPE=Release}
        ]

        args = [
            std_cmake_args,
            cmake_compile_args,
            witty_args,
            witty_cmake_args,
            optional_args,
        ].flatten.join(" ")

        mkdir "build" do
            system "cmake ../ #{args}"
            system "make -j5"
            system "make install"
        end
    end

    test do
        system "false"
    end
end
