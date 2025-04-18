

set -ex



test -f $PREFIX/lib/libc++.dylib
test -f $PREFIX/lib/libc++.a
test -f $PREFIX/lib/libc++experimental.a
test ! -d $PREFIX/include/c++
exit 0
