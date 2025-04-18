#!/bin/bash

# Prevent running ldconfig when cross-compiling.
if [[ "${BUILD}" != "${HOST}" ]]; then
  echo "#!/usr/bin/env bash" > ldconfig
  chmod +x ldconfig
  export PATH=${PWD}:$PATH
fi

export CFLAGS="${CFLAGS} -DSQLITE_DQS=0 \
                         -DSQLITE_ENABLE_COLUMN_METADATA \
                         -DSQLITE_ENABLE_DBSTAT_VTAB \
                         -DSQLITE_ENABLE_DESERIALIZE \
                         -DSQLITE_ENABLE_EXPLAIN_COMMENTS \
                         -DSQLITE_ENABLE_FTS3 \
                         -DSQlITE_ENABLE_FTS3_PARENTHESIS \
                         -DSQLITE_ENABLE_FTS3_TOKENIZER \
                         -DSQLITE_ENABLE_FTS4 \
                         -DSQLITE_ENABLE_FTS5 \
                         -DSQLITE_ENABLE_GEOPOLY \
                         -DSQLITE_ENABLE_JSON1 \
                         -DSQLITE_ENABLE_MATH_FUNCTIONS \
                         -DSQLITE_ENABLE_PREUPDATE_HOOK \
                         -DSQLITE_ENABLE_RTREE \
                         -DSQLITE_ENABLE_SESSION \
                         -DSQLITE_ENABLE_STAT4 \
                         -DSQLITE_ENABLE_STMTVTAB \
                         -DSQLITE_ENABLE_UNLOCK_NOTIFY \
                         -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT \
                         -DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
                         -DSQLITE_MAX_EXPR_DEPTH=10000 \
                         -DSQLITE_MAX_VARIABLE_NUMBER=250000 \
                         -DSQLITE_SECURE_DELETE \
                         -DSQLITE_SOUNDEX \
                         -DSQLITE_STRICT_SUBTYPE=1 \
                         -DSQLITE_THREADSAFE=1 \
                         -DSQLITE_USE_URI"

if [[ $target_platform =~ linux.* ]]; then
    export CFLAGS="${CFLAGS} -DHAVE_PREAD64 -DHAVE_PWRITE64"
fi

if [[ "$target_platform" == "linux-ppc64le" ]]; then
    export PPC64LE="--build=ppc64le-linux"
fi

./configure --prefix=${PREFIX} \
            --build=${BUILD} \
            --host=${HOST} \
            --enable-threadsafe \
            --enable-load-extension \
            --disable-static \
            --with-readline-header="${CONDA_PREFIX}/include/readline/readline.h" \
            CFLAGS="${CFLAGS} -I${PREFIX}/include" \
            LDFLAGS="${LDFLAGS} -L${PREFIX}/lib" \
            ${PPC64LE}

make -j${CPU_COUNT} ${VERBOSE_AT}
make install

# We can remove this when we start using the new conda-build.
find $PREFIX -name '*.la' -delete
