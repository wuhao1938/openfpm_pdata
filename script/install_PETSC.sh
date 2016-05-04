#! /bin/bash

# check if the directory $1/PETSC exist

if [ -d "$1/PETSC" ]; then
  echo "PETSC already installed"
  exit 0
fi

## If some dependencies has been installed feed them to PETSC

MUMPS_extra_libs=""

configure_options=""
configure_options_scalapack=""
configure_options_superlu=""
configure_trilinos_options=" -D TPL_ENABLE_MPI=ON -D Trilinos_ENABLE_OpenMP=ON"
configure_options_hypre=""

if [ -d "$1/OPENBLAS" ]; then
  configure_options="$configure_options --with-blas-lib=$1/OPENBLAS/lib/libopenblas.a --with-lapack-lib=$1/OPENBLAS/lib/libopenblas.a"
  configure_trilinos_options="$configure_trilinos_options -D TPL_ENABLE_BLAS=ON -D BLAS_LIBRARY_NAMES=openblas -D BLAS_LIBRARY_DIRS=$1/OPENBLAS/lib -D TPL_ENABLE_LAPACK=ON -D LAPACK_LIBRARY_NAMES=openblas -D LAPACK_LIBRARY_DIRS=$1/OPENBLAS/lib -D TPL_ENABLE_Netcdf=OFF -DTPL_ENABLE_GLM=OFF "
  configure_options_superlu="$configure_options_superlu -Denable_blaslib=OFF  -DTPL_BLAS_LIBRARIES=$1/OPENBLAS/lib/libopenblas.a "
  configure_options_hypre="--with-blas-libs=-lopenblas --with-blas-lib-dirs=$1/OPENBLAS/lib --with-lapack-libs=-lopenblas  --with-lapack-lib-dirs=$1/OPENBLAS/lib "
  configure_options_scalapack="$configure_options_scalapack -D LAPACK_LIBRARIES=$1/OPENBLAS/lib/libopenblas.a -D BLAS_LIBRARIES=$1/OPENBLAS/lib/libopenblas.a"

fi

if [ -d "$1/PARMETIS" ]; then
  configure_options="$configure_options --with-parmetis=yes  --with-parmetis-dir=$1/PARMETIS/ "
  configure_options_superlu="-DTPL_PARMETIS_INCLUDE_DIRS=$1/PARMETIS/include;$1/METIS/include -DTPL_PARMETIS_LIBRARIES=$1/PARMETIS/lib/libparmetis.a;$1/METIS/lib/libmetis.so $configure_options_superlu"
fi

if [ -d "$1/METIS" ]; then
  configure_options="$configure_options --with-metis=yes --with-metis-dir=$1/METIS  "
fi

if [ -d "$1/HDF5" ]; then
  configure_options="$configure_options --with-hdf5=yes --with-hdf5-dir=$1/HDF5  "
fi

if [ -d "$1/SUITESPARSE" ]; then
  configure_options="$configure_options --with-suitesparse=yes --with-suitesparse-dir=$1/SUITESPARSE "
fi

if [ -d "$1/BOOST" ]; then
  configure_options="$configure_options --with-boost=yes --with-boost-dir=$1/BOOST "
fi

if [ -d "$1/MPI" ]; then
  configure_trilinos_options="$configure_trilinos_options -D MPI_BASE_DIR=$1/MPI "
fi

### It seem that the PETSC --download-packege option has several problems and cannot produce
### a valid compilation command for most of the package + it seem also seem that some library
### are compiled without optimization enabled, so we provide manual installation for that packages

if [ ! -d "$1/TRILINOS" ]; then
  rm trilinos-12.6.1-Source.tar.gz
  rm -rf trilinos-12.6.1-Source
  wget http://ppmcore.mpi-cbg.de/upload/trilinos-12.6.1-Source.tar.gz
  if [ $? -ne 0 ]; then
    echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
    exit 1
  fi
  tar -xf trilinos-12.6.1-Source.tar.gz
  cd trilinos-12.6.1-Source
  mkdir build
  cd build
  cmake -D CMAKE_INSTALL_PREFIX:PATH=$1/TRILINOS -D CMAKE_BUILD_TYPE=RELEASE -D Trilinos_ENABLE_TESTS=OFF  -D Trilinos_ENABLE_ALL_PACKAGES=ON $configure_trilinos_options  ../.

  make -j 4
  if [ $? -eq 0 ]; then
    make install
    configure_options="$configure_options --with-trilinos=yes -with-trilinos-dir=$1/TRILINOS"
  fi
else
  echo "Trilinos already installed"
  configure_options="$configure_options --with-trilinos=yes -with-trilinos-dir=$1/TRILINOS"
fi

### Scalapack installation

if [ ! -d "$1/SCALAPACK" ]; then
  rm scalapack-2.0.2.tgz
  rm -rf scalapack-2.0.2
  wget http://ppmcore.mpi-cbg.de/upload/scalapack-2.0.2.tgz
  if [ $? -ne 0 ]; then
    echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
    exit 1
  fi
  tar -xf scalapack-2.0.2.tgz
  cd scalapack-2.0.2
  mkdir build
  cd build
  cmake -D CMAKE_EXE_LINKER_FLAGS=-pthread  -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_Fortran_FLAGS_RELEASE=-fpic -D MPI_C_COMPILER_FLAGS=-fpic -D MPI_Fortran_COMPILER_FLAGS=-fpic -D CMAKE_C_FLAGS=-fpic -D CMAKE_INSTALL_PREFIX="$1/SCALAPACK" $configure_options_scalapack ../.
  make -j 4
  if [ $? -eq 0 ]; then
    make install
    configure_options="$configure_options --with-scalapack=yes -with-scalapack-dir=$1/SCALAPACK"
  fi
else
  echo "Scalapack already installed"
  configure_options="$configure_options --with-scalapack=yes -with-scalapack-dir=$1/SCALAPACK"
fi


### MUMPS installation

if [ ! -d "$1/MUMPS" ]; then
  rm MUMPS_5.0.1.tar.gz
  rm -rf MUMPS_5.0.1
  wget http://ppmcore.mpi-cbg.de/upload/MUMPS_5.0.1.tar.gz
  if [ $? -ne 0 ]; then
    echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
    exit 1
  fi
  tar -xf MUMPS_5.0.1.tar.gz
  cd MUMPS_5.0.1
  cp Make.inc/Makefile.inc.generic Makefile.inc
 
  if [ x"$platform" = x"osx"  ]; then
    # installation for OSX

    echo "OSX TO DO BYE"
    exit 1

  else
    # Installation for linux

    sed -i "/CC\s\+=\scc/c\CC = mpicc" Makefile.inc
    sed -i "/FC\s\+=\sf90/c\FC = mpif90" Makefile.inc
    sed -i "/FL\s\+=\sf90/c\FL = mpif90" Makefile.inc

    sed -i "/SCALAP\s\+=\s-lscalapack\s-lblacs/c\SCALAP = -L$1/SCALAPACK/lib -L$1/OPENBLAS/lib -lscalapack" Makefile.inc
    sed -i "/LIBBLAS\s\+=\s\-lopenblas/c\LIBBLAS = -lopenblas" Makefile.inc

    sed -i "/OPTF\s\+=\s\-O/c\OPTF = -fpic -O3" Makefile.inc
    sed -i "/OPTC\s\+=\s\-O\s-I./c\OPTC = -fpic -O3 -I." Makefile.inc
    sed -i "/OPTL\s\+=\s\-O/c\OPTL = -fpic -O3" Makefile.inc

    sed -i "/LIBBLAS\s=\s-lblas/c\LIBBLAS = -lopenblas" Makefile.inc

  fi
  make -j 4
  
  if [ $? -eq 0 ]; then
    ## Copy LIB and include in the target directory

    mkdir $1/MUMPS
    cp -r include $1/MUMPS
    cp -r lib $1/MUMPS
    configure_options="$configure_options --with-mumps=yes --with-mumps-lib=\"$1/MUMPS/lib/libdmumps.a $1/MUMPS/lib/libmumps_common.a $1/MUMPS/lib/libpord.a\"  --with-mumps-include=$1/MUMPS/include"
  fi

else
  echo "MUMPS already installed"
  configure_options="$configure_options --with-mumps=yes --with-mumps-include=$1/MUMPS/include"
  MUMPS_extra_lib="$1/MUMPS/lib/libdmumps.a $1/MUMPS/lib/libmumps_common.a $1/MUMPS/lib/libpord.a"
fi

## SuperLU installation

if [ ! -d "$1/SUPERLU_DIST" ]; then
  rm superlu_dist_4.3.tar.gz
  rm -rf SuperLU_DIST_4.3
  wget http://ppmcore.mpi-cbg.de/upload/superlu_dist_4.3.tar.gz
  if [ $? -ne 0 ]; then
    echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
    exit 1
  fi
  tar -xf superlu_dist_4.3.tar.gz
  cd SuperLU_DIST_4.3

  if [ x"$platform" = x"osx"  ]; then
    # installation for OSX

    echo "OSX TO DO BYE"
    exit 1

  else
    # Installation for linux

    sed -i "/DSuperLUroot\s\+=\s\${HOME}\/Release_Codes\/SuperLU_DIST_4.3/c\DSuperLUroot = ../" make.inc
#    sed -i "/DSUPERLULIB\s\+=\s../lib//c\DSUPERLULIB = ../lib/libsuperlu_4.3.a" make.inc
    sed -i "/BLASLIB\s\+=/c\BLASLIB = $1/OPENBLAS/lib/libopenblas.a" make.inc
    sed -i "/LOADOPTS\s\+=\s-openmp/c\LOADOPTS = -fopenmp" make.inc
    sed -i "/PARMETIS_DIR\s\+=\/project\/projectdirs\/mp127\/parmetis-4.0.3-g/c\PARMETIS_DIR := $1/PARMETIS" make.inc

    sed -i "/METISLIB\s:=\s-L\${PARMETIS_DIR}\/build\/Linux-x86_64\/libmetis\s-lmetis/c\METISLIB := -L$1/METIS/lib -lmetis" make.inc
    sed -i "/PARMETISLIB\s:=\s-L\${PARMETIS_DIR}\/build\/Linux-x86_64\/libparmetis\s-lparmetis/c\PARMETISLIB := -L$1/PARMETIS/lib -lparmetis" make.inc

    sed -i "/I_PARMETIS\s:=\s-I\${PARMETIS_DIR}\/include\s-I\${PARMETIS_DIR}\/metis\/include/c\I_PARMETIS := -I$1/PARMETIS/include -I$1/METIS/include" make.inc
    sed -i "/CC\s\+=\scc/c\CC = mpicc" make.inc
    sed -i "/FORTRAN\s\+=\sftn/c\FORTRAN = mpif90" make.inc
    sed -i "/CFLAGS\s\+=\s-fast\s-m64\s-std=c99\s-Wall\s-openmp\s\\\/c\CFLAGS =-fpic -O3 -m64 -std=c99 -Wall -fopenmp \$(I_PARMETIS) -DDEBUGlevel=0 -DPRNTlevel=0 -DPROFlevel=0" make.inc
    sed -i "/\s\$(I_PARMETIS)\s-DDEBUGlevel=0\s-DPRNTlevel=0\s-DPROFlevel=0\s\\\/c\ " make.inc

  fi

  make

  if [ $? -eq 0 ]; then
    mkdir $1/SUPERLU_DIST
    mkdir $1/SUPERLU_DIST/include
    cp -r lib/ $1/SUPERLU_DIST
    cp SRC/*.h $1/SUPERLU_DIST/include
    configure_options="$configure_options --with-superlu_dist=yes --with-superlu_dist-lib=$1/SUPERLU_DIST/lib/libsuperlu_dist_4.3.a --with-superlu_dist-include=$1/SUPERLU_DIST/include/"
  fi

else
  echo "SUPERLU already installed"
  configure_options="$configure_options --with-superlu_dist=yes --with-superlu_dist-lib=$1/SUPERLU_DIST/lib/libsuperlu_dist_4.3.a --with-superlu_dist-include=$1/SUPERLU_DIST/include/"
fi

## HYPRE installation

if [ ! -d "$1/HYPRE" ]; then
  rm hypre-2.11.0.tar.gz
  rm -rf hypre-2.11.0
  wget http://ppmcore.mpi-cbg.de/upload/hypre-2.11.0.tar.gz
  if [ $? -ne 0 ]; then
    echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
    exit 1
  fi
  tar -xf hypre-2.11.0.tar.gz
  cd hypre-2.11.0

  cd src

  ./configure CFLAGS=-fpic  $configure_options_hypre --prefix=$1/HYPRE
  make -j 4

  if [ $? -eq 0 ]; then
    make install
    configure_options="$configure_options --with-hypre=yes -with-hypre-dir=$1/HYPRE"
  fi

else
  echo "HYPRE already installed"
  configure_options="$configure_options --with-hypre=yes -with-hypre-dir=$1/HYPRE"
fi
 

rm petsc-lite-3.6.4.tar.gz
rm -rf petsc-3.6.4
wget http://ppmcore.mpi-cbg.de/upload/petsc-lite-3.6.4.tar.gz
if [ $? -ne 0 ]; then
  echo -e "\033[91;5;1m FAILED Installation require an Internet connection \033[0m"
  exit 1
fi
tar -xf petsc-lite-3.6.4.tar.gz
cd petsc-3.6.4

echo "./configure --with-cxx-dialect=C++11 --with-mpi-dir=$1/MPI  $configure_options  --prefix=$1/PETSC"

./configure --with-cxx-dialect=C++11 --with-openmp=yes  --with-mpi-dir=$1/MPI  $configure_options --with-mumps-lib="$MUMPS_extra_lib"  --prefix=$1/PETSC
make all test
make install

# if empty remove the folder
if [ ! "$(ls -A $1/PETSC)" ]; then
   rm -rf $1/PETSC
fi
