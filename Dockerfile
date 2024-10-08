FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential build tools and dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    gfortran \
    wget \
    git \
    python3 \
    python3-pip \
    python3-dev \
    libopenmpi-dev \
    openmpi-bin \
    liblapack-dev \
    liblapack64-dev \
    libfftw3-dev \
    libfftw3-mpi-dev \
    netcdf-bin \
    m4 \
    make \
    zlib1g-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Build and install parallel HDF5
WORKDIR /tmp
RUN wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.5/hdf5-1.14.5.tar.gz && \
    tar xzf hdf5-1.14.5.tar.gz && \
    cd hdf5-1.14.5 && \
    CC=mpicc FC=mpifort \
    ./configure --prefix=/usr \
                --enable-parallel \
                --enable-fortran \
                --enable-shared \
                --enable-build-mode=production && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -rf hdf5-1.14.5.tar.gz hdf5-1.14.5

# Set up environment variables
ENV CC=mpicc \
    FC=mpifort \
    F77=mpifort \
    CPPFLAGS="-I/usr/include" \
    LDFLAGS="-L/usr/lib" \
    LD_LIBRARY_PATH="/usr/lib" \
    HDF5_DIR="/usr" \
    HDF5_DISABLE_VERSION_CHECK=1

# Build and install parallel NetCDF-C
RUN wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz && \
    tar xzf netcdf-c-4.9.2.tar.gz && \
    cd netcdf-c-4.9.2 && \
    ./configure --prefix=/usr \
                --enable-shared \
                --enable-parallel4 \
                --enable-netcdf4 && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -rf netcdf-c-4.9.2.tar.gz netcdf-c-4.9.2

# Build and install parallel NetCDF-Fortran
RUN wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz && \
    tar xzf netcdf-fortran-4.6.1.tar.gz && \
    cd netcdf-fortran-4.6.1 && \
    ./configure --prefix=/usr \
                --enable-shared && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -rf netcdf-fortran-4.6.1.tar.gz netcdf-fortran-4.6.1

# Update ldconfig to include the new libraries
RUN ldconfig

# Verify NetCDF installations
RUN nc-config --has-parallel4
RUN nf-config --has-parallel4

# Create symbolic links for Python (if they don't exist)
RUN if [ ! -e /usr/bin/python ]; then ln -s /usr/bin/python3 /usr/bin/python; fi && \
    if [ ! -e /usr/bin/pip ]; then ln -s /usr/bin/pip3 /usr/bin/pip; fi

# Install common scientific Python packages
RUN pip install --no-cache-dir \
    numpy \
    scipy \
    h5py \
    netCDF4 \
    mpi4py

# Clone GS2 repository
WORKDIR /opt
RUN git clone --recurse-submodules https://bitbucket.org/gyrokinetics/gs2.git

# Configure and build GS2
WORKDIR /opt/gs2
ENV GK_SYSTEM=gnu-gfortran

# Find netcdf.mod location
RUN find /usr -name "netcdf.mod" | xargs dirname > netcdf_mod_path.txt

# Build GS2
RUN mkdir -p ~/.local/gs2 && \
    cp Makefiles/Makefile.$GK_SYSTEM ~/.local/gs2/Makefile && \
    if [ ! -e /usr/include/fftw3.f03 ]; then \
        find /usr -name fftw3.f03 -exec ln -s {} /usr/include/fftw3.f03 \; ; \
    fi && \
    NETCDF_MOD_DIR=$(cat netcdf_mod_path.txt) && \
    FFLAGS="-I${NETCDF_MOD_DIR} -I/usr/include $(nc-config --fflags)" \
    make -I Makefiles

# Add GS2 to PATH
ENV PATH="/opt/gs2/bin:${PATH}"

# Set working directory for user
WORKDIR /app

# Command to run when container starts
CMD ["/bin/bash"]