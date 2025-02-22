# Stage 1: Build AWS CLI v2
ARG ALPINE_VERSION=3.19
FROM python:3.11-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.15.0

# Install required dependencies for building AWS CLI
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake

# Clone AWS CLI repository (specific version)
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli

# Configure and build AWS CLI
RUN ./configure --with-install-type=portable-exe --with-download-deps
RUN make
RUN make install

# Remove unnecessary files to reduce image size
RUN rm -rf \
    /usr/local/lib/aws-cli/aws_completer \
    /usr/local/lib/aws-cli/awscli/data/ac.index \
    /usr/local/lib/aws-cli/awscli/examples
RUN find /usr/local/lib/aws-cli/awscli/data -name completions-1*.json -delete
RUN find /usr/local/lib/aws-cli/awscli/botocore/data -name examples-1.json -delete
RUN (cd /usr/local/lib/aws-cli; for a in *.so*; do test -f /lib/$a && rm $a; done)

# Stage 2: Extract Session Manager Plugin
FROM debian:bullseye-slim as plugin-builder
WORKDIR /tmp

# Install dpkg to extract the Debian package
RUN apt-get update && apt-get install -y dpkg curl && rm -rf /var/lib/apt/lists/*

# Download the latest AWS Session Manager Plugin package
RUN curl -sSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o session-manager-plugin.deb

# Extract only the required binary from the .deb package
RUN dpkg-deb -x session-manager-plugin.deb extracted

# Copy only the session-manager-plugin binary to keep the image small
RUN cp extracted/usr/local/sessionmanagerplugin/bin/session-manager-plugin /session-manager-plugin

# Stage 3: Final minimal image
FROM alpine:${ALPINE_VERSION}

# Install essential utilities
RUN apk add --no-cache bash util-linux libc6-compat ncurses

# Copy AWS CLI from the builder stage
COPY --from=builder /usr/local/lib/aws-cli/ /usr/local/lib/aws-cli/
RUN ln -s /usr/local/lib/aws-cli/aws /usr/local/bin/aws

# Copy the AWS Session Manager Plugin from the plugin-builder stage
COPY --from=plugin-builder /session-manager-plugin /usr/local/bin/session-manager-plugin
RUN chmod +x /usr/local/bin/session-manager-plugin

# Copy the aws-ssm-session.sh script into the container
COPY ./aws-ssm-session.sh /usr/local/bin/aws-ssm-session.sh
RUN chmod +x /usr/local/bin/aws-ssm-session.sh

# Set the script as the entrypoint
ENTRYPOINT ["/usr/local/bin/aws-ssm-session.sh"]