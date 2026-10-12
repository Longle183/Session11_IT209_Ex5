# ==========================================
# Multi-stage Dockerfile cho Spring Boot Gradle
# ==========================================

# Stage 1: Build & Package JAR
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Sao chép Gradle Wrapper và file cấu hình trước để tận dụng cache
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# Cấp quyền thực thi cho Gradle Wrapper
RUN chmod +x ./gradlew

# Tải trước dependencies (nếu có cache sẽ tiết kiệm thời gian)
RUN ./gradlew dependencies --no-daemon || true

# Sao chép mã nguồn
COPY src src

# Đóng gói file JAR (bỏ qua test vì đã test thành công ở Job test trong CI)
RUN ./gradlew bootJar -x test --no-daemon

# ==========================================
# Stage 2: Runtime image gọn nhẹ
# ==========================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Tạo user phi đặc quyền (non-root) để tăng cường bảo mật
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Sao chép file JAR đã build từ stage 1
COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar

# Khai báo cổng mặc định của Spring Boot
EXPOSE 8080

# Chạy ứng dụng Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]
