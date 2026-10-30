FROM dart:stable AS build

WORKDIR /app/backend
COPY packages/request_contract /app/packages/request_contract
COPY backend/pubspec.* ./
RUN dart pub get
COPY backend/ .
RUN dart compile exe bin/server.dart -o bin/server
RUN dart compile exe bin/notification_worker.dart -o bin/notification_worker

FROM dart:stable

RUN apt-get update && apt-get install -y --no-install-recommends fonts-dejavu-core && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/backend/bin/server /app/bin/server
COPY --from=build /app/backend/bin/notification_worker /app/bin/notification_worker
COPY backend/templates /app/templates

EXPOSE 8080

CMD ["/app/bin/server"]