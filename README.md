# Bài 5: Nối Job Tự Động Build & Push Docker Image Sau Khi Test Gradle Xanh

## 1. Mục Tiêu
- **Tách biệt quy trình CI (Continuous Integration):** Chia pipeline thành 2 Jobs riêng biệt với trách nhiệm độc lập:
  - `Job test`: Kiểm thử mã nguồn tự động với Gradle Wrapper (`./gradlew test`) và đóng gói mã nguồn (`./gradlew bootJar`).
  - `Job docker-build`: Đóng gói container image từ `Dockerfile` và đẩy lên GitHub Container Registry (`ghcr.io`).
- **Ràng buộc thứ tự thực thi (Job Dependency):** Sử dụng từ khóa `needs: test` để thiết lập quan hệ phụ thuộc: chỉ khi `Job test` hoàn thành thành công (trạng thái xanh - Success), `Job docker-build` mới được kích hoạt chạy. Nếu `Job test` thất bại (trạng thái đỏ - Failed), `Job docker-build` sẽ tự động bị bỏ qua (trạng thái xám - Skipped).

---

## 2. Cấu Trúc Dự Án
```text
homework/session_11/ex5/
├── .github/
│   └── workflows/
│       └── ci.yml               # Workflow GitHub Actions gồm 2 job liên kết
├── gradle/
│   └── wrapper/                 # Gradle wrapper
├── src/
│   ├── main/java/.../DemoApplication.java
│   └── test/java/.../DemoApplicationTests.java
├── .gitignore
├── build.gradle
├── Dockerfile                   # Multi-stage Dockerfile cho Spring Boot
├── gradlew
├── gradlew.bat
├── settings.gradle
└── README.md                    # Hướng dẫn chi tiết & báo cáo thực hiện
```

---

## 3. Nội Dung Tệp Cấu Hình

### 3.1. Workflow CI (`.github/workflows/ci.yml`)
```yaml
name: CI Workflow - Test & Docker Build

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  # ========================================================
  # Job 1: Test & Build JAR (Gradle)
  # ========================================================
  test:
    name: Run Unit Tests & Build JAR
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK 17
        uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Cấp quyền thực thi cho Gradle Wrapper
        run: chmod +x gradlew

      - name: Thực thi JUnit Test và Đóng gói JAR
        run: ./gradlew test bootJar

  # ========================================================
  # Job 2: Build & Push Docker Image lên GHCR
  # Chỉ thực thi khi Job test kết thúc thành công (needs: test)
  # ========================================================
  docker-build:
    name: Build and Push Docker Image
    needs: test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Đăng nhập vào GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}

      - name: Chuyển tên repository thành chữ thường (Lowercase)
        run: |
          echo "IMAGE_NAME=ghcr.io/$(echo "${{ github.repository }}" | tr '[:upper:]' '[:lower:]')" >> $GITHUB_ENV

      - name: Đóng gói và Đẩy Docker Image lên GHCR
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ${{ env.IMAGE_NAME }}:${{ github.sha }}
```

### 3.2. Dockerfile Multi-Stage (`Dockerfile`)
```dockerfile
# Multi-stage Dockerfile cho Spring Boot Gradle
# Stage 1: Build & Package JAR
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./
RUN chmod +x ./gradlew
RUN ./gradlew dependencies --no-daemon || true

COPY src src
RUN ./gradlew bootJar -x test --no-daemon

# Stage 2: Runtime image tối ưu dung lượng
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 4. Hướng Dẫn Thực Hành & Kiểm Tra

### Bước 1: Đẩy mã nguồn lên GitHub Repository
Mở terminal tại thư mục bài làm `homework/session_11/ex5`:
```powershell
git init
git add .
git commit -m "feat: configure 2-job CI pipeline with needs dependency"
git branch -M main
git remote add origin <URL_REPOSITORY_CUA_BAN>
git push -u origin main --force
```

### Bước 2: Quan sát Biểu Đồ Workflow (Job Dependency Graph)
1. Mở Repository trên GitHub -> chọn tab **Actions**.
2. Chọn lần chạy workflow mới nhất vừa được kích hoạt.
3. Trên giao diện tổng quan của workflow, quan sát **sơ đồ trực quan (DAG graph)**:
   - Xuất hiện 2 khối: `Run Unit Tests & Build JAR` (job `test`) và `Build and Push Docker Image` (job `docker-build`).
   - Có **mũi tên liên kết** chỉ từ job `test` sang job `docker-build`, minh chứng cho mối quan hệ `needs: test`.
4. Khi job `test` hoàn thành với dấu tích xanh, job `docker-build` sẽ bắt đầu chạy và đẩy Docker image lên `ghcr.io`.

### Bước 3: Kiểm thử cơ chế Fail-Fast (Làm đứt JUnit Test)
1. Mở file [DemoApplicationTests.java](file:///src/test/java/com/example/demo/DemoApplicationTests.java).
2. Sửa một hàm assertion khiến test bị sai (ví dụ thay đổi kết quả mong muốn):
   ```java
   @Test
   void sampleUnitTest() {
       int expected = 999; // Cố tình làm đứt test
       int actual = 5 + 5;
       org.junit.jupiter.api.Assertions.assertEquals(expected, actual, "Math calculation should match");
   }
   ```
3. Commit và push thay đổi lên GitHub:
   ```powershell
   git add src/test/java/com/example/demo/DemoApplicationTests.java
   git commit -m "test: simulate broken junit test"
   git push origin main
   ```
4. Quan sát trên tab **Actions**:
   - Job `test` chạy và kết thúc với trạng thái **Failed** (dấu x đỏ).
   - Job `docker-build` **tự động chuyển sang trạng thái Skipped** (bị bỏ qua, biểu tượng màu xám).
   - Không có Docker Image lỗi nào được build hoặc đẩy lên registry, hoàn thành trọn vẹn mục tiêu an toàn của quy trình CI/CD!

---

## 5. Sản Phẩm Nộp Bài
1. Tệp kịch bản: [.github/workflows/ci.yml](file:///.github/workflows/ci.yml).
2. Tệp [Dockerfile](file:///Dockerfile) và mã nguồn Spring Boot kèm unit test.
3. Ảnh chụp màn hình:
   - **Ảnh 1:** Biểu đồ sơ đồ Workflow trên GitHub Actions hiển thị mũi tên nối từ job `test` sang job `docker-build` (Cả 2 jobs đều xanh).
   - **Ảnh 2:** Biểu đồ Workflow khi test bị đứt (Job `test` màu đỏ, job `docker-build` màu xám - Skipped).
