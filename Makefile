# ----------------------------------------------------------------------------
# Copyright (c) 2013, KOBAYASHI Daisuke
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# ----------------------------------------------------------------------------

GCC_VERSION = 4.7.2
BINUTILS_VERSION = 2.22
MINGWW64_VERSION = 2.0.7
GMP_VERSION = 5.0.5
MPFR_VERSION = 3.1.1
MPC_VERSION = 1.0.1

PREFIX = /usr/local
XPREFIX = $(PREFIX)/$(TARGET)/$(GCC_VERSION)
BUILD = $(shell cc -dumpmachine)

PATH = $(XPREFIX)/bin:/usr/local/bin:/usr/bin:/bin

FETCH = curl -OLJ
# FETCH = wget
TAR = tar

GCC_ = gcc-$(GCC_VERSION)
BINUTILS_ = binutils-$(BINUTILS_VERSION)
MINGWW64_ = mingw-w64-v$(MINGWW64_VERSION)
GMP_ = gmp-$(GMP_VERSION)
MPFR_ = mpfr-$(MPFR_VERSION)
MPC_ = mpc-$(MPC_VERSION)

32bit: TARGET = i686-w64-mingw32
64bit: TARGET = x86_64-w64-mingw32
multi: TARGET = x86_64-w64-mingw32
32bit 64bit multi: $(GCC_).stamp

$(GCC_).tar.bz2:
	# $(FETCH) ftp://gcc.gnu.org/pub/gcc/releases/$(GCC_)/$@
	$(FETCH) http://ftpmirror.gnu.org/gcc/$(GCC_)/$@

$(BINUTILS_).tar.bz2:
	# $(FETCH) ftp://ftp.gnu.org/gnu/binutils/$@
	$(FETCH) http://ftpmirror.gnu.org/binutils/$@

$(MINGWW64_).tar.gz:
	$(FETCH) http://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/$@/download

$(GMP_).tar.bz2:
	# $(FETCH) ftp://ftp.gmplib.org/pub/$(GMP_)/$@
	$(FETCH) http://ftpmirror.gnu.org/gmp/$@

$(MPFR_).tar.bz2:
	$(FETCH) http://www.mpfr.org/$(MPFR_)/$@

$(MPC_).tar.gz:
	$(FETCH) http://www.multiprecision.org/mpc/download/$@

.SECONDARY: $(GCC_) $(BINUTILS_) $(MINGWW64_) $(GMP_) $(MPFR_) $(MPC_)

gmp-%: gmp-%.tar.bz2
	$(TAR) jxf $<
	touch $@

mpfr-%: mpfr-%.tar.bz2
	$(TAR) jxf $<
	touch $@

mpc-%: mpc-%.tar.gz
	$(TAR) zxf $<
	touch $@

binutils-%: binutils-%.tar.bz2
	$(TAR) jxf $<
	touch $@

gcc-%: gcc-%.tar.bz2
	$(TAR) jxf $<
	touch $@

mingw-w64-v%: mingw-w64-v%.tar.gz
	$(TAR) zxf $<
	touch $@

.SECONDARY: $(GCC_).stamp $(GCC_).core.stamp $(BINUTILS_).stamp \
	$(MINGWW64_).headers.stamp $(MINGWW64_).crt.stamp \
	$(GMP_).stamp $(MPFR_).stamp $(MPC_).stamp

gmp-%.stamp: BUILDDIR = gmp-$*.build
gmp-%.stamp: OPTS = --prefix=$(PWD) --disable-shared
gmp-%.stamp: gmp-%
	$(BUILDLIB)

mpfr-%.stamp: BUILDDIR = mpfr-$*.build
mpfr-%.stamp: OPTS = --prefix=$(PWD) --with-gmp=$(PWD) --disable-shared
mpfr-%.stamp: mpfr-% $(GMP_).stamp
	$(BUILDLIB)

mpc-%.stamp: BUILDDIR = mpc-$*.build
mpc-%.stamp: OPTS = --prefix=$(PWD) --with-gmp=$(PWD) --with-mpfr=$(PWD) --disable-shared
mpc-%.stamp: mpc-% $(GMP_).stamp $(MPFR_).stamp
	$(BUILDLIB)

define BUILDLIB
mkdir -p $(BUILDDIR)
cd $(BUILDDIR) && ../$</configure $(OPTS)
$(MAKE) -C $(BUILDDIR)
$(MAKE) -C $(BUILDDIR) install
touch $@
endef

BINUTILS_OPTS = --prefix=$(XPREFIX) --target=$(TARGET)
ifeq ($(MAKECMDGOALS),multi)
BINUTILS_OPTS += --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32
else
BINUTILS_OPTS += --disable-multilib
endif

binutils-%.stamp: BUILDDIR = binutils-$*.build
binutils-%.stamp: binutils-%
	mkdir -p $(BUILDDIR)
	cd $(BUILDDIR) && ../$</configure $(BINUTILS_OPTS)
	$(MAKE) -C $(BUILDDIR)
	$(MAKE) -C $(BUILDDIR) install
	touch $@

mingw-w64-v%.headers.stamp: BUILDDIR = mingw-w64-v$*.headers.build
mingw-w64-v%.headers.stamp: mingw-w64-v%
	mkdir -p $(BUILDDIR)
	cd $(BUILDDIR) && ../$</mingw-w64-headers/configure --prefix=$(XPREFIX) --build=$(BUILD) --host=$(TARGET)
	$(MAKE) -C $(BUILDDIR) install
	cd $(XPREFIX) && [ -d mingw ] || ln -s $(TARGET) mingw
ifeq ($(MAKECMDGOALS),multi)
	cd $(XPREFIX)/mingw && [ -d lib64 ] || ln -s lib lib64
endif
	touch $@

GCC_OPTS = --prefix=$(XPREFIX) --target=$(TARGET) \
		--with-gmp=$(PWD) --with-mpfr=$(PWD) --with-mpc=$(PWD) \
		--enable-languages=c,c++
ifeq ($(MAKECMDGOALS),multi)
GCC_OPTS += --enable-targets=all
else
GCC_OPTS += --disable-multilib
endif

gcc-%.core.stamp: BUILDDIR = gcc-$*.build
gcc-%.core.stamp: gcc-% $(GMP_).stamp $(MPFR_).stamp $(MPC_).stamp \
		$(BINUTILS_).stamp $(MINGWW64_).headers.stamp
	mkdir -p $(BUILDDIR)
	cd $(BUILDDIR) && ../$</configure $(GCC_OPTS)
	$(MAKE) -C $(BUILDDIR) all-gcc
	$(MAKE) -C $(BUILDDIR) install-gcc
	touch $@

MINGWW64_OPTS = --prefix=$(XPREFIX) --build=$(TARGET) --host=$(TARGET)
ifeq ($(MAKECMDGOALS),multi)
MINGWW64_OPTS += --enable-lib32
endif

mingw-w64-v%.crt.stamp: BUILDDIR = mingw-w64-v$*.crt.build
mingw-w64-v%.crt.stamp: mingw-w64-v% mingw-w64-v%.headers.stamp $(GCC_).core.stamp
	mkdir -p $(BUILDDIR)
	cd $(BUILDDIR) && CC= CXX= CPP= LD= ../$</mingw-w64-crt/configure $(MINGWW64_OPTS)
	$(MAKE) -C $(BUILDDIR)
	$(MAKE) -C $(BUILDDIR) install
	touch $@

gcc-%.stamp: BUILDDIR = gcc-$*.build
gcc-%.stamp: gcc-% gcc-%.core.stamp $(MINGWW64_).crt.stamp
	$(MAKE) -C $(BUILDDIR)
	$(MAKE) -C $(BUILDDIR) install
	touch $@

clean:
	$(RM) *.stamp
	$(RM) -r *.build
.PHONY: clean
