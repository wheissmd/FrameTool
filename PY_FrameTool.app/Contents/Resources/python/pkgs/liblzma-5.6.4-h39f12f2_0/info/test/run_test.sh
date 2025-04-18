

set -ex



test ! -f ${PREFIX}/lib/liblzma.a
test ! -f ${PREFIX}/lib/liblzma${SHLIB_EXT}
test -f ${PREFIX}/lib/liblzma.*.dylib
exit 0
