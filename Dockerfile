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

COPY --from=build /root/.cache/rod /home/user/.cache/rod
RUN ln -s /home/user/.cache/rod/browser/$(ls /home/user/.cache/rod/browser)/chrome /usr/bin/chrome
RUN touch /.dockerenv

COPY --from=build /rod/rod-manager /usr/bin/

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

# run as user
RUN groupadd -r user && \
    useradd -r -g user user && \
    echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'user:password' | chpasswd
RUN mkdir -p /home/user/.config
RUN chown user:user /usr/bin/rod-manager
RUN chown -R user:user /home/user

USER user

ENV XDG_CONFIG_HOME=/tmp/.chromium
ENV XDG_CACHE_HOME=/tmp/.chromium
ENV DISPLAY=:0
ENV SCREEN_SIZE="1600x900x16"
ENV VNC_PASS="123456"

# process reaper
ENTRYPOINT ["dumb-init", "--"]

#CMD rod-manager
CMD Xvfb -screen 0 $SCREEN_SIZE -ac & \
#		x11vnc -storepasswd $VNC_PASS /tmp/vncpass & \
#		x11vnc -rfbauth /tmp/vncpass -display :0 -forever & \
		rod-manager --allow-all