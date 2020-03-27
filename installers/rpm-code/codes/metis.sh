#!/bin/bash

metis_main() {
    codes_dependencies parmetis
    #http://glaros.dtc.umn.edu/gkhome/metis/metis/download
    codes_download_foss metis-5.1.0.tar.gz
    make config prefix="${codes_dir[prefix]}"
    codes_make_install
}
