# ---------------------------------------------------------------
# 1) Multi-stage build: Pull the connect-client binary
# ---------------------------------------------------------------
ARG CONNECT_CLIENT_VERSION=0.9.0
FROM public.cr.seqera.io/platform/connect-client:${CONNECT_CLIENT_VERSION} AS connect

# ---------------------------------------------------------------
# 2) Build stage: Clone and build IGV webapp
# ---------------------------------------------------------------
FROM node:18-slim AS builder

WORKDIR /build

# Install git to clone the repository
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Clone IGV webapp repository
RUN git clone https://github.com/igvteam/igv-webapp.git .

# Install dependencies and build
RUN npm install && npm run build

# ---------------------------------------------------------------
# 3) Runtime stage: Serve the built webapp
# ---------------------------------------------------------------
FROM node:18-slim

# Just for the automation at Seqera
LABEL org.opencontainers.image.source="https://github.com/seqeralabs/custom-studios-examples"

WORKDIR /app

# Install http-server to serve the static files
RUN npm install -g http-server

# Copy IGV webapp files from builder stage
COPY --from=builder /build/index.html /app/
COPY --from=builder /build/igvwebConfig.js /app/
COPY --from=builder /build/favicon.ico /app/
# Copy dist contents (including JS bundles) directly to /app root
COPY --from=builder /build/dist/ /app/
COPY --from=builder /build/css /app/css
COPY --from=builder /build/img /app/img
COPY --from=builder /build/resources /app/resources

# Copy custom startup script
COPY generate-session.sh /usr/local/bin/generate-session.sh

# Make script executable
RUN chmod +x /usr/local/bin/generate-session.sh

# Environment variable for default genome (can be overridden)
ENV IGV_GENOME=hg38

# Add backports repository and install specific btrfs-progs version
RUN echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free-firmware" | tee -a /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y btrfs-progs=6.14-1~bpo12+1 && \
    rm -rf /var/lib/apt/lists/*

# Copy connect-client from the first stage
COPY --from=connect /usr/bin/connect-client /usr/bin/connect-client

# "Install" connect-client (sets up any needed config)
RUN /usr/bin/connect-client --install

# ---------------------------------------------------------------
# 4) Launch with connect-client --entrypoint (for Seqera Platform)
# ---------------------------------------------------------------
ENTRYPOINT ["/usr/bin/connect-client", "--entrypoint"]

# ---------------------------------------------------------------
# 5) Command: Generate session and serve IGV webapp on CONNECT_TOOL_PORT
# ---------------------------------------------------------------
# The port is set by CONNECT_TOOL_PORT environment variable
# First run the session generator, then start http-server
CMD ["/bin/bash", "-c", "generate-session.sh && http-server /app -p $CONNECT_TOOL_PORT -a 0.0.0.0 --cors"]
