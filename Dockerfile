# ---- Stage 1: Build Cloudrift CLI ----
FROM golang:1.24 AS cli-build

WORKDIR /cli
RUN git clone https://github.com/inayathulla/cloudrift.git . && \
    CGO_ENABLED=0 GOOS=linux go build -o cloudrift main.go

# ---- Stage 2: Build API Server ----
FROM golang:1.24 AS api-build

WORKDIR /api
COPY server/go.mod ./
COPY server/main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o cloudrift-api main.go

# ---- Stage 3: Build Flutter Web ----
FROM ghcr.io/cirruslabs/flutter:stable AS web-build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# ---- Stage 4: Run ----
FROM nginx:alpine

# Install supervisor, Terraform CLI, and dependencies
RUN apk add --no-cache supervisor unzip && \
    wget -qO /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin/ && \
    rm /tmp/terraform.zip

# Create terraform working directory and provider plugin cache
RUN mkdir -p /etc/cloudrift/terraform /var/cache/terraform-plugins
ENV TF_PLUGIN_CACHE_DIR=/var/cache/terraform-plugins

# Copy Cloudrift CLI binary + config + examples (policies are embedded in the binary)
COPY --from=cli-build /cli/cloudrift /usr/local/bin/cloudrift
COPY --from=cli-build /cli/config /etc/cloudrift/config
COPY --from=cli-build /cli/examples /etc/cloudrift/examples

# Copy API server binary
COPY --from=api-build /api/cloudrift-api /usr/local/bin/cloudrift-api

# Copy Flutter web build
COPY --from=web-build /app/build/web /usr/share/nginx/html

# Copy nginx and supervisor configs
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
