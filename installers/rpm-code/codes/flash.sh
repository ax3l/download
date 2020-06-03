#!/bin/bash

flash_main() {
    codes_dependencies hypre
    codes_download_proprietary "flash/FLASH-4.6.2.tar.gz" "FLASH4.6.2"
    flash_patch_makefile
    install -d 755 "${codes_dir[share]}"/flash4
    local n
    for n in CapLaserBELLA RTFlame; do
        flash_make_and_install_type "$n"
    done
}

flash_make_and_install_type() {
    local type=$1
    "flash_setup_$type" "$type"
    cd "$type"
    codes_make
    # POSIT: sirepo.sim_data.flash.SimData.flash_exe_path assumes flash4-flashType
    install -m 755 flash4 "${codes_dir[bin]}"/flash4-"$type"
    # POSIT: sirepo.sim_data.flash.SimData.flash_setup_units_path assumes flash4/setup_units-flashType
    install -m 444 setup_units "${codes_dir[share]}"/flash4/setup_units-"$type"
    cd ..
}

flash_patch_makefile() {
    local d=$(dirname "$BIVIO_MPI_LIB")
    patch sites/Prototypes/Linux/Makefile.h <<EOF
6c6
< MPI_PATH   = /usr/local/mpich2/
---
> MPI_PATH   = $d/
8,9c8,9
< HDF5_PATH  = /usr/local/hdf5
< HYPRE_PATH = /usr/local/hypre
---
> HDF5_PATH  = $d/
> HYPRE_PATH = ${codes_dir[prefix]}
EOF
}

flash_setup_CapLaserBELLA() {
    local type=$1
    codes_download_proprietary "flash/$type-4.6.2.tar.gz" "source"
    cd ..
    ./setup "$type" -objdir="$type" -auto -2d -nxb=16 -nyb=16 +hdf5typeio \
            species=fill,wall +mtmmmt +usm3t +mgd mgd_meshgroups=6 \
            -parfile=caplaser_basic.par +laser ed_maxPulses=1 \
            ed_maxPulseSections=4 ed_maxBeams=1
}

flash_setup_RTFlame() {
    local type=$1
    ./setup "$type" -objdir="$type" -2d -auto -nxb=16 -nyb=16
}
