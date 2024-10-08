FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables for include paths - preserve existing values if any
ENV LIBRARY_PATH="${LIBRARY_PATH:+${LIBRARY_PATH}:}/usr/include" \
    CPATH="${CPATH:+${CPATH}:}/usr/include" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}/usr/lib:/usr/lib/x86_64-linux-gnu" \
    PATH="/usr/include:${PATH}"

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
    libhdf5-dev \
    libhdf5-serial-dev \
    hdf5-tools \
    libopenmpi-dev \
    openmpi-bin \
    libnetcdf-dev \
    libnetcdff-dev \
    netcdf-bin \
    liblapack-dev \
    liblapack64-dev \
    libfftw3-dev \
    libfftw3-mpi-dev \
    m4 \
    make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# Find and link necessary module files
RUN find /usr -name "netcdf.mod" -exec dirname {} \; | xargs -I {} ln -sf {}/*.mod /usr/include/ || true

# Build GS2
RUN mkdir -p ~/.local/gs2 && \
    cp Makefiles/Makefile.$GK_SYSTEM ~/.local/gs2/Makefile && \
    if [ ! -e /usr/include/fftw3.f03 ]; then \
        find /usr -name fftw3.f03 -exec ln -s {} /usr/include/fftw3.f03 \; ; \
    fi && \
    FFLAGS="-I/usr/include $(nc-config --fflags)" make -I Makefiles GK_SYSTEM=gnu-gfortran

# Add GS2 to PATH
ENV PATH="/opt/gs2/bin:${PATH}"

# Set working directory for user
WORKDIR /app

# Command to run when container starts
CMD ["/bin/bash"]