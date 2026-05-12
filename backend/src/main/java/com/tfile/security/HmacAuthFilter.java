package com.tfile.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Xác thực HMAC-SHA256: payload {@code METHOD:requestURI:X-Timestamp} (timestamp epoch millis), so khớp
 * {@code X-Signature} (hex chữ thường). Sai lệch thời gian tối đa 5 phút.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
@Slf4j
public class HmacAuthFilter extends OncePerRequestFilter {

  private static final long MAX_SKEW_MS = 5 * 60 * 1000L;

  @Value("${admin.password:}")
  private String adminPassword;

  @Override
  protected void doFilterInternal(
      @NonNull HttpServletRequest request,
      @NonNull HttpServletResponse response,
      @NonNull FilterChain filterChain)
      throws ServletException, IOException {

    if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
      filterChain.doFilter(request, response);
      return;
    }

    String uri = request.getRequestURI();
    if ("/api/health".equals(uri)) {
      filterChain.doFilter(request, response);
      return;
    }

    if (adminPassword == null || adminPassword.isBlank()) {
      log.warn("ADMIN_PASSWORD is not set; rejecting protected request");
      response.sendError(HttpStatus.SERVICE_UNAVAILABLE.value(), "Server misconfiguration");
      return;
    }

    String tsHeader = request.getHeader("X-Timestamp");
    String sigHeader = request.getHeader("X-Signature");
    if (tsHeader == null || tsHeader.isBlank() || sigHeader == null || sigHeader.isBlank()) {
      response.sendError(HttpStatus.UNAUTHORIZED.value(), "Missing authentication headers");
      return;
    }

    long clientTs;
    try {
      clientTs = Long.parseLong(tsHeader.trim());
    } catch (NumberFormatException e) {
      response.sendError(HttpStatus.UNAUTHORIZED.value(), "Invalid X-Timestamp");
      return;
    }

    long now = System.currentTimeMillis();
    if (Math.abs(now - clientTs) > MAX_SKEW_MS) {
      response.sendError(HttpStatus.UNAUTHORIZED.value(), "Stale timestamp");
      return;
    }

    String payload =
        request.getMethod().toUpperCase() + ":" + uri + ":" + tsHeader.trim();
    byte[] expectedMac;
    try {
      expectedMac = hmacSha256(adminPassword, payload);
    } catch (NoSuchAlgorithmException | InvalidKeyException e) {
      log.error("HMAC init failed", e);
      response.sendError(HttpStatus.INTERNAL_SERVER_ERROR.value(), "Auth error");
      return;
    }

    byte[] provided;
    try {
      provided = HexFormat.of().parseHex(sigHeader.trim().toLowerCase());
    } catch (IllegalArgumentException e) {
      response.sendError(HttpStatus.UNAUTHORIZED.value(), "Invalid X-Signature encoding");
      return;
    }

    if (!MessageDigest.isEqual(expectedMac, provided)) {
      response.sendError(HttpStatus.UNAUTHORIZED.value(), "Bad signature");
      return;
    }

    filterChain.doFilter(request, response);
  }

  private static byte[] hmacSha256(String secret, String payload)
      throws NoSuchAlgorithmException, InvalidKeyException {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
    return mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
  }
}
