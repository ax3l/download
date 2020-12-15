#!/bin/bash

trilinos_main() {
    codes_dependencies metis
    codes_download https://github.com/trilinos/Trilinos/archive/trilinos-release-13-0-1.tar.gz Trilinos-trilinos-release-13-0-1 trilinos 13.0.1
    codes_cmake \
        -DCMAKE_INSTALL_PREFIX:PATH="${codes_dir[prefix]}" \
        -DCMAKE_CXX_FLAGS:STRING="-DMPICH_IGNORE_CXX_SEEK -fPIC" \
        -DCMAKE_C_FLAGS:STRING="-DMPICH_IGNORE_CXX_SEEK -fPIC" \
        -DCMAKE_CXX_STANDARD:STRING="11" \
        -DCMAKE_Fortran_FLAGS:STRING="-fPIC" \
        -DCMAKE_BUILD_TYPE:STRING=Release \
        -DMETIS_LIBRARY_DIRS="${codes_dir[lib]}" \
        -DMPI_C_COMPILER:FILEPATH=mpicc \
        -DMPI_CXX_COMPILER:FILEPATH=mpicxx \
        -DMPI_Fortran_COMPILER:FILEPATH=mpif77 \
        -DTPL_ENABLE_DLlib:BOOL=OFF \
        -DTPL_ENABLE_QT:BOOL=OFF \
        -DMPI_BASE_DIR="$(dirname "$BIVIO_MPI_LIB")" \
        -DTPL_ENABLE_MPI=ON \
        -DTPL_ENABLE_BLAS:BOOL=ON \
        -DTPL_ENABLE_LAPACK:BOOL=ON \
        -DTPL_ENABLE_METIS:BOOL=ON \
        -DTPL_ENABLE_ParMETIS:BOOL=ON \
        -DTrilinos_ENABLE_Amesos:BOOL=ON \
        -DTrilinos_ENABLE_Amesos2:BOOL=ON \
        -DTrilinos_ENABLE_AztecOO:BOOL=ON \
        -DTrilinos_ENABLE_Belos:BOOL=ON \
        -DTrilinos_ENABLE_Epetra:BOOL=ON \
        -DTrilinos_ENABLE_EpetraExt:BOOL=ON \
        -DTrilinos_ENABLE_Galeri:BOOL=ON \
        -DTrilinos_ENABLE_Ifpack:BOOL=ON \
        -DTrilinos_ENABLE_Isorropia:BOOL=ON \
        -DTrilinos_ENABLE_ML:BOOL=ON \
        -DTrilinos_ENABLE_MueLu:BOOL=ON \
        -DTrilinos_ENABLE_NOX:BOOL=ON \
        -DTrilinos_ENABLE_Teuchos:BOOL=ON \
        -DTrilinos_ENABLE_Tpetra:BOOL=ON \
        -DTrilinos_ENABLE_TESTS:BOOL=OFF
    codes_make_install
}
