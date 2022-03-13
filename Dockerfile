# stage 1 (planner) - generate a recipe file for dependencies
FROM rust AS planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json



# stage 2 (cacher) - build our dependencies
FROM rust AS cacher
WORKDIR /app
#empty image so install cargo-chef again
RUN cargo install cargo-chef
# copy recipe.json output from the planner stage to 'cook' here
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json



# stage 3 (builder) - use the official rust docker image
FROM rust AS builder
# create appuser for security
ENV USER=web
ENV UID=1001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

# copy the app into the docker image
COPY . /app
# set the work dir
WORKDIR /app
# copy dependencies files here to use
COPY --from=cacher /app/target target
# copy other dependencies to use here
COPY --from=cacher /usr/local/cargo /usr/local/cargo
# build the app in release mode, not debug
RUN cargo build --release
# use google distroless as runtime image
FROM gcr.io/distroless/cc-debian11
# Import user info from builder
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
# copy built app from the builder stage
COPY --from=builder /app/target/release/ActixWebTaskService /app/ActixWebTaskService
WORKDIR /app

USER web:web

# Start the application
CMD ["./ActixWebTaskService"]