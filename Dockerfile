FROM ubuntu:22.04

ARG TARGETARCH

WORKDIR /app

RUN apt-get update
RUN apt-get install -y wget

RUN wget https://download.hiveos.farm/hub/stable/latest/hub-linux-${TARGETARCH}.tar.gz
RUN tar xzf hub-linux-${TARGETARCH}.tar.gz

WORKDIR /app/hub-linux-${TARGETARCH}
COPY install.sh .
RUN chmod +x install.sh
RUN ./install.sh -y --no-restart

CMD ["/opt/asic-hub/hub", "-c", "/etc/asic-hub/config.toml"]

EXPOSE 8800
