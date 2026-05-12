package com.tfile.config;

import javax.sql.DataSource;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.beans.factory.annotation.Value;

@Configuration
public class DataSourceConfig {

  @Bean
  @Primary
  public DataSource dataSource(@Value("${DATABASE_URL}") String databaseUrl) {
    return DataSourceBuilder.create().url(JdbcUrlConverter.toJdbcUrl(databaseUrl)).build();
  }
}
