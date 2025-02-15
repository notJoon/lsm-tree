FROM golang:1.22-bullseye

# Install required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone and install gno
RUN git clone https://github.com/gnolang/gno.git && \
    cd gno && \
    make install.gno

# Copy the LSM tree project
COPY . .

# Set default command
CMD ["gno", "test", "./lsm", "-root-dir", "./gno", "-v"]
