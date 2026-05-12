package com.tfile.config;

public final class JdbcUrlConverter {

  private JdbcUrlConverter() {}

  /**
   * Chuyển {@code postgres://} / {@code postgresql://} (Neon, Render) sang {@code jdbc:postgresql://}.
   */
  public static String toJdbcUrl(String url) {
    if (url == null || url.isBlank()) {
      throw new IllegalStateException("DATABASE_URL is required");
    }
    String u = url.trim();
    if (u.startsWith("jdbc:")) {
      return u;
    }
    if (u.startsWith("postgres://") || u.startsWith("postgresql://")) {
      int schemeEnd = u.indexOf("://");
      if (schemeEnd < 0) {
        throw new IllegalStateException("Invalid DATABASE_URL");
      }
      return "jdbc:postgresql://" + u.substring(schemeEnd + 3);
    }
    throw new IllegalStateException("Unsupported DATABASE_URL; use postgres://, postgresql://, or jdbc:postgresql://");
  }
}
