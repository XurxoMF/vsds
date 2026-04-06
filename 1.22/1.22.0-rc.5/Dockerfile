# Use the official .NET runtime image as the base image
FROM mcr.microsoft.com/dotnet/runtime:10.0

# Define ENV variables
ENV SERVER_URL="https://cdn.vintagestory.at/gamefiles/unstable/vs_server_linux-x64_1.22.0-rc.5.tar.gz" \
    SERVER_PORT="42420" \
    UID="1000" \
    GID="1000"

# Install some needed packages
RUN apt-get update && \
    apt-get install -y curl netcat-openbsd gosu && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /server && mkdir /data

# Remove the default ubuntu user and create the vintagestory user and group
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd -g 1000 vintagestory && \
    useradd -u 1000 -g vintagestory -m -s /bin/bash vintagestory

# Exposeserver port
EXPOSE $SERVER_PORT

# Healthcheck
HEALTHCHECK --start-period=1m --interval=5s CMD nc -z 127.0.0.1 $SERVER_PORT

# Change to the vintagestory user's home directory
WORKDIR /server

# Download and extract Vintagestory Server files
RUN curl -L "$SERVER_URL" -o server.tar.gz && \
    tar -xzf server.tar.gz && \
    rm server.tar.gz

# Set permissions for the server and data directory
RUN chown -R vintagestory:vintagestory /data /server

# Volume for persistent Vintagestory data
VOLUME ["/data"]

# Add entrypoint script to handle server startup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run the server
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/server/VintagestoryServer", "--dataPath", "/data"]