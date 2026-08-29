FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      xfce4 xfce4-terminal dbus-x11 tigervnc-standalone-server \
      novnc websockify openssh-server sudo curl wget git nano ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 6080 22
ENTRYPOINT ["/entrypoint.sh"]
