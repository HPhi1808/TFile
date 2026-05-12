package com.tfile;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class TfileApplication {

  public static void main(String[] args) {
    loadDotEnv();
    SpringApplication.run(TfileApplication.class, args);
  }

  /**
   * Đọc {@code backend/.env} (thư mục làm việc khi chạy {@code mvn spring-boot:run}). Chỉ gán system property
   * khi biến môi trường OS chưa có — không ghi đè biến đã export / cấu hình IDE.
   */
  private static void loadDotEnv() {
    Dotenv dotenv = Dotenv.configure().ignoreIfMissing().load();
    dotenv
        .entries()
        .forEach(
            e -> {
              if (System.getenv(e.getKey()) == null && System.getProperty(e.getKey()) == null) {
                System.setProperty(e.getKey(), e.getValue());
              }
            });
  }
}
