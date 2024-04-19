# To build the image:
#     docker build -t ghcr.io/go-rod/rod -f lib/docker/Dockerfile .
#

# build rod-manager
FROM golang:1.19-bullseye as build

ARG goproxy="https://goproxy.io,direct"

COPY . /rod
WORKDIR /rod
RUN go env -w GOPROXY=$goproxy
RUN go build ./lib/launcher/rod-manager
RUN go run ./lib/utils/get-browser

FROM ubuntu:jammy

RUN groupadd -r user && useradd -r -g user user

COPY --from=build /root/.cache/rod /home/user/.cache/rod
RUN ln -s /home/user/.cache/rod/browser/$(ls /root/.cache/rod/browser)/chrome /usr/bin/chrome
RUN touch /.dockerenv

COPY --from=build /rod/rod-manager /usr/bin/

RUN chown -R user:user /home/user/.cache/rod
RUN chown user:user /usr/bin/rod-manager

ARG apt_sources="http://mirrors.ustc.edu.cn"

RUN sed -i "s|http://archive.ubuntu.com|$apt_sources|g" /etc/apt/sources.list && \
    apt-get update > /dev/null && \
    apt-get install --no-install-recommends -y \
    sudo \
    # chromium dependencies
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    libgtk-3-0 \
    libgbm1 \
    ca-certificates \
    # fonts
    fonts-liberation fonts-noto-color-emoji fonts-noto-cjk \
    # timezone
    tzdata \
    # process reaper
    dumb-init \
    # headful mode support, for example: $ xvfb-run chromium-browser --remote-debugging-port=9222
    xvfb \
    xserver-xorg x11vnc && \
    # cleanup
    rm -rf /var/lib/apt/lists/*

USER user

# process reaper
ENTRYPOINT ["dumb-init", "--"]

CMD rod-manager
