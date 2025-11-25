FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
WORKDIR /source
COPY nuget.config nuget.config
COPY Build/Common.csproj Build/Common.csproj
COPY BTCPayServer.Abstractions/BTCPayServer.Abstractions.csproj BTCPayServer.Abstractions/BTCPayServer.Abstractions.csproj
COPY BTCPayServer/BTCPayServer.csproj BTCPayServer/BTCPayServer.csproj
COPY BTCPayServer.Common/BTCPayServer.Common.csproj BTCPayServer.Common/BTCPayServer.Common.csproj
COPY BTCPayServer.Rating/BTCPayServer.Rating.csproj BTCPayServer.Rating/BTCPayServer.Rating.csproj
COPY BTCPayServer.Data/BTCPayServer.Data.csproj BTCPayServer.Data/BTCPayServer.Data.csproj
COPY BTCPayServer.Client/BTCPayServer.Client.csproj BTCPayServer.Client/BTCPayServer.Client.csproj
RUN cd BTCPayServer && dotnet restore
COPY BTCPayServer.Common/. BTCPayServer.Common/.
COPY BTCPayServer.Rating/. BTCPayServer.Rating/.
COPY BTCPayServer.Data/. BTCPayServer.Data/.
COPY BTCPayServer.Client/. BTCPayServer.Client/.
COPY BTCPayServer.Abstractions/. BTCPayServer.Abstractions/.
COPY BTCPayServer/. BTCPayServer/.
COPY Build/Version.csproj Build/Version.csproj
ARG CONFIGURATION_NAME=Release
ARG GIT_COMMIT
RUN cd BTCPayServer && dotnet publish -p:GitCommit=${GIT_COMMIT} --configuration ${CONFIGURATION_NAME} --output /app/

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

RUN apk add --no-cache bash iproute2 openssh-client ca-certificates su-exec \
    && addgroup -g 523 btcpayserver \
    && adduser -D -G btcpayserver -u 523 btcpayserver

ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    BTCPAY_DATADIR=/datadir \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    HOME=/home/btcpayserver

WORKDIR /app
VOLUME /datadir

COPY --from=builder /app /app
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

RUN mkdir -p /datadir /home/btcpayserver/.btcpayserver \
    && chown -R btcpayserver:btcpayserver /datadir /app /home/btcpayserver \
    && chmod +x /app/docker-entrypoint.sh

EXPOSE 23000

USER root

ENTRYPOINT ["/app/docker-entrypoint.sh"]
